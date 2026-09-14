import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:ai_vision/core/camera/camera_preview_widget.dart';
import 'package:ai_vision/core/camera/camera_providers.dart';
import 'package:ai_vision/core/ml/detection_engine.dart';
import 'package:ai_vision/core/ml/ml_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      // Use the default camera selected in settings
      final defaultCamera = ref.read(defaultCameraProvider);
      final cameraIndex = await cameraService.getCameraIndex(
        defaultCamera == 'front'
            ? CameraLensDirection.front
            : CameraLensDirection.back,
      );
      await cameraService.initialize(cameraIndex: cameraIndex);

      // Apply frame skip interval from settings (Inference FPS)
      final inferenceFps = ref.read(inferenceFpsProvider);
      cameraService.setFrameSkipInterval((30 / inferenceFps).round().clamp(1, 10));

      // Initialize the face detection engine (loads TFLite model)
      final engine = ref.read(faceDetectionEngineProvider);
      await engine.initialize();

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
      }).catchError((e) {
        debugPrint('Face detection error: $e');
      });
    });
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