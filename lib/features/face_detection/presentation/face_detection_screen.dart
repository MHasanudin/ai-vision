import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:ai_vision/core/camera/camera_preview_widget.dart';
import 'package:ai_vision/core/camera/camera_service.dart';
import 'package:ai_vision/core/camera/camera_providers.dart';
import 'package:ai_vision/core/database/app_database.dart';
import 'package:ai_vision/core/ml/detection_engine.dart';
import 'package:ai_vision/core/ml/ml_providers.dart';
import 'package:ai_vision/features/person_management/data/person_providers.dart';

class FaceDetectionScreen extends ConsumerStatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  ConsumerState<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends ConsumerState<FaceDetectionScreen> {
  FaceDetectionResult? _latestResult;
  bool _isCameraReady = false;
  String? _errorMessage;
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  /// Biodata of the recognized person (null if not recognized).
  FaceRecognitionResult? _recognitionResult;

  /// Cache of person data loaded from database (personId -> Person).
  Map<int, Person>? _personCache;
  List<MapEntry<String, List<double>>>? _embeddingCandidates;

  /// Throttle recognition: only run every N frames.
  int _frameSkipCounter = 0;
  static const int _recognitionFrameSkip = 5; // recognition every 5 frames

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadEmbeddings();
  }

  /// Load all face embeddings + persons from database into memory for fast matching.
  Future<void> _loadEmbeddings() async {
    try {
      final faceDao = ref.read(faceEmbeddingDaoProvider);
      final personDao = ref.read(personDaoProvider);
      final embeddings = await faceDao.getAllFaceEmbeddings();
      final persons = await personDao.getAllPersons();

      // Build person lookup: personId -> Person
      final cache = <int, Person>{};
      for (final p in persons) {
        cache[p.id] = p;
      }

      // Build embedding candidates: personId_string -> List<double>
      final candidates = <MapEntry<String, List<double>>>[];
      for (final emb in embeddings) {
        // Convert stored bytes back to List<double>
        final floatList = Float32List.view(emb.embedding.buffer);
        final doubleList = floatList.toList();
        candidates.add(MapEntry('${emb.personId}', doubleList));
      }

      if (mounted) {
        setState(() {
          _personCache = cache;
          _embeddingCandidates = candidates;
        });
      }

      debugPrint('Loaded ${candidates.length} embeddings for ${cache.length} persons');
    } catch (e) {
      debugPrint('Failed to load embeddings: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      final defaultCamera = ref.read(defaultCameraProvider);
      final cameraIndex = await cameraService.getCameraIndex(
        defaultCamera == 'front'
            ? CameraLensDirection.front
            : CameraLensDirection.back,
      );
      await cameraService.initialize(cameraIndex: cameraIndex);

      final inferenceFps = ref.read(inferenceFpsProvider);
      cameraService.setFrameSkipInterval((30 / inferenceFps).round().clamp(1, 10));

      final engine = ref.read(faceDetectionEngineProvider);
      await engine.initialize();

      // Also init recognition engine
      final recEngine = ref.read(faceRecognitionEngineProvider);
      await recEngine.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }

      _subscribeToFrames();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera unavailable.\nPlease check camera permission.';
        });
      }
    }
  }

  void _subscribeToFrames() {
    final cameraService = ref.read(cameraServiceProvider);
    final engine = ref.read(faceDetectionEngineProvider);

    cameraService.frameStream.listen((frame) {
      _updateFps();

      engine.detect(frame.data, width: frame.width, height: frame.height).then((result) {
        if (mounted) {
          setState(() {
            _latestResult = result as FaceDetectionResult;
          });
        }
        // Run recognition (throttled)
        _runRecognition(frame);
      }).catchError((e) {
        debugPrint('Face detection error: $e');
      });
    });
  }

  void _runRecognition(CameraFrame frame) async {
    _frameSkipCounter++;
    if (_frameSkipCounter % _recognitionFrameSkip != 0) return;
    if (_latestResult == null || _latestResult!.boxes.isEmpty) {
      if (_recognitionResult != null) {
        setState(() {
          _recognitionResult = null;
        });
      }
      return;
    }
    if (_embeddingCandidates == null || _embeddingCandidates!.isEmpty) {
      return; // no embeddings registered yet
    }

    final recEngine = ref.read(faceRecognitionEngineProvider);
    if (!recEngine.isInitialized) return;

    try {
      final threshold = ref.read(faceRecognitionThresholdProvider);

      // Take the largest face
      final largest = _latestResult!.boxes.reduce((a, b) {
        final areaA = a.rect.width * a.rect.height;
        final areaB = b.rect.width * b.rect.height;
        return areaA >= areaB ? a : b;
      });

      // Extract embedding from the detected face region
      final embedding = await recEngine.extractEmbeddingFromCrop(
        frame.data,
        faceRect: largest.rect,
        frameWidth: frame.width,
        frameHeight: frame.height,
      );

      if (embedding == null) return;

      // Find best match among registered candidates
      final match = recEngine.findBestMatchIn(
        embedding,
        _embeddingCandidates!,
        threshold,
      );

      if (match != null) {
        final personId = int.tryParse(match.$1);
        final person = personId != null && _personCache != null
            ? _personCache![personId]
            : null;

        final dob = person?.dateOfBirth;
        final dobText = dob == null
            ? ''
            : '${dob.day}/${dob.month}/${dob.year}';

        if (mounted) {
          setState(() {
            _recognitionResult = FaceRecognitionResult(
              personName: person?.fullName ?? 'Person #${match.$1}',
              dateOfBirth: dobText,
              personId: person?.employeeId ?? 'ID: ${match.$1}',
              similarity: match.$2,
              faceRect: largest.rect,
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _recognitionResult = FaceRecognitionResult(
              personName: 'Unknown',
              dateOfBirth: '',
              personId: '',
              similarity: 0,
              faceRect: largest.rect,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Recognition error: $e');
    }
  }

  void _updateFps() {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
    
    if (elapsed >= 1000) {
      if (mounted) {
        setState(() {
          _fps = (_frameCount * 1000 / elapsed).round();
          _frameCount = 0;
          _lastFpsUpdate = now;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    final cameraService = ref.read(cameraServiceProvider);
    await cameraService.switchCamera();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Back to Dashboard',
        ),
        title: const Text('Face Detection & Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _isCameraReady ? _switchCamera : null,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (!_isCameraReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final cameraService = ref.watch(cameraServiceProvider);

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreviewWidget(
                cameraService: cameraService,
                mirrorFrontCamera: ref.watch(mirrorFrontCameraProvider),
                child: _buildFaceOverlay(),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_fps FPS',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildFaceInfoPanel(),
      ],
    );
  }

  Widget _buildFaceOverlay() {
    final result = _latestResult;
    if (result == null || result.boxes.isEmpty) {
      return const Center(
        child: Text(
          'No face detected',
          style: TextStyle(color: Colors.white, fontSize: 16, shadows: [
            Shadow(blurRadius: 4, color: Colors.black),
          ]),
        ),
      );
    }

    return CustomPaint(
      painter: _FaceBoxPainter(result.boxes),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildFaceInfoPanel() {
    final result = _latestResult;
    final faceCount = result?.boxes.length ?? 0;
    final rec = _recognitionResult;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faceCount > 0 ? '$faceCount face(s) detected' : 'No face detected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (result != null && result.boxes.isNotEmpty)
            ...result.boxes.map((box) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          box.label,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        '${(box.confidence * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                )),
          // Recognition / biodata section
          if (rec != null) ...[
            const Divider(height: 24),
            if (rec.personName == 'Unknown' || rec.personName.isEmpty)
              Row(
                children: [
                  const Icon(Icons.person_off, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Unknown person',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.personName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                  ),
                ],
              ),
              if (rec.personId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.badge, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      rec.personId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              if (rec.dateOfBirth.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.cake, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      rec.dateOfBirth,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.verified, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Match: ${(rec.similarity * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Custom painter for face bounding boxes
class _FaceBoxPainter extends CustomPainter {
  final List<DetectionBox> boxes;

  _FaceBoxPainter(this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final rect = Rect.fromLTRB(
        box.rect.left * size.width,
        box.rect.top * size.height,
        box.rect.right * size.width,
        box.rect.bottom * size.height,
      );

      // Draw face bounding box
      final paint = Paint()
        ..color = Colors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(rect, paint);

      // Draw label
      final label = '${box.label} ${(box.confidence * 100).toStringAsFixed(1)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height,
        textPainter.width + 8,
        textPainter.height,
      );

      final adjustedRect = labelRect.top < 0
          ? Rect.fromLTWH(rect.left, rect.top, textPainter.width + 8, textPainter.height)
          : labelRect;

      canvas.drawRect(adjustedRect, Paint()..color = Colors.cyan);
      textPainter.paint(
        canvas,
        Offset(adjustedRect.left + 4, adjustedRect.top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes;
  }
}