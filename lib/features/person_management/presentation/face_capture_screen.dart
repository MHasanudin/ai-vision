import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:ai_vision/core/camera/camera_preview_widget.dart';
import 'package:ai_vision/core/camera/camera_providers.dart';
import 'package:ai_vision/core/database/app_database.dart';
import 'package:ai_vision/core/ml/ml_providers.dart';
import 'package:ai_vision/features/person_management/data/person_providers.dart';

/// Screen to capture a face for a person and store its embedding.
class FaceCaptureScreen extends ConsumerStatefulWidget {
  final int personId;

  const FaceCaptureScreen({super.key, required this.personId});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  bool _isCameraReady = false;
  String? _errorMessage;
  bool _isCapturing = false;
  bool _captured = false;
  List<double>? _embedding;
  Rect? _faceRect;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      // Prefer front camera for face capture
      final cameraIndex = await cameraService.getCameraIndex(CameraLensDirection.front);
      await cameraService.initialize(cameraIndex: cameraIndex);

      // Initialize the face recognition engine (loads MobileFaceNet)
      final engine = ref.read(faceRecognitionEngineProvider);
      await engine.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera unavailable.\nPlease check camera permission.';
        });
      }
    }
  }

  Future<void> _captureFace() async {
    if (_isCapturing || _captured) return;
    setState(() {
      _isCapturing = true;
    });

    try {
      final cameraService = ref.read(cameraServiceProvider);
      final engine = ref.read(faceRecognitionEngineProvider);

      // Wait for the next frame
      final frame = await cameraService.frameStream.first;

      // Detect faces
      final faceDetector = ref.read(faceDetectionEngineProvider);
      final faceResult = await faceDetector.detect(
        frame.data,
        width: frame.width,
        height: frame.height,
      );

      if (faceResult.boxes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No face detected. Please look at the camera.')),
          );
        }
        return;
      }

      // Take the largest face
      final largest = faceResult.boxes.reduce((a, b) {
        final areaA = a.rect.width * a.rect.height;
        final areaB = b.rect.width * b.rect.height;
        return areaA >= areaB ? a : b;
      });

      // Extract embedding from the face crop
      final embedding = await engine.extractEmbeddingFromCrop(
        frame.data,
        faceRect: largest.rect,
        frameWidth: frame.width,
        frameHeight: frame.height,
      );

      if (embedding == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to extract face embedding. Please try again.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _embedding = embedding;
          _faceRect = largest.rect;
          _captured = true;
        });
      }
    } catch (e) {
      debugPrint('Face capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _saveEmbedding() async {
    final embedding = _embedding;
    if (embedding == null) return;

    try {
      final dao = ref.read(faceEmbeddingDaoProvider);
      // Convert embedding (List<double>) to bytes
      final bytes = Float32List.fromList(embedding).buffer.asUint8List();
      await dao.insertFaceEmbedding(
        FaceEmbeddingsCompanion.insert(
          personId: widget.personId,
          embedding: bytes,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face registered successfully')),
        );
        context.go('/persons/${widget.personId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save face: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/persons/${widget.personId}'),
          tooltip: 'Back',
        ),
        title: const Text('Capture Face'),
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
                mirrorFrontCamera: true,
                child: _buildOverlay(),
              ),
              // Status indicator
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
                    _captured ? 'Face captured ✓' : 'Look at the camera',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildOverlay() {
    if (_faceRect == null) {
      return const Center(
        child: Text(
          'Position your face in the frame',
          style: TextStyle(color: Colors.white, fontSize: 16, shadows: [
            Shadow(blurRadius: 4, color: Colors.black),
          ]),
        ),
      );
    }

    return CustomPaint(
      painter: _FaceCapturePainter(_faceRect!),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_captured && _embedding != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Face captured successfully!\nEmbedding size: ${_embedding!.length}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isCapturing || _captured ? null : _captureFace,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.face_retouching_natural),
                  label: Text(_isCapturing ? 'Capturing...' : 'Capture Face'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _captured && _embedding != null ? _saveEmbedding : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Painter to draw the face capture guide box
class _FaceCapturePainter extends CustomPainter {
  final Rect faceRect;

  _FaceCapturePainter(this.faceRect);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      faceRect.left * size.width,
      faceRect.top * size.height,
      faceRect.right * size.width,
      faceRect.bottom * size.height,
    );

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceCapturePainter oldDelegate) {
    return oldDelegate.faceRect != faceRect;
  }
}