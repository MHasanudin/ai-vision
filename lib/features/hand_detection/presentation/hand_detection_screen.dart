import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_vision/core/camera/camera_preview_widget.dart';
import 'package:ai_vision/core/camera/camera_providers.dart';
import 'package:ai_vision/core/ml/detection_engine.dart';
import 'package:ai_vision/core/ml/ml_providers.dart';

class HandDetectionScreen extends ConsumerStatefulWidget {
  const HandDetectionScreen({super.key});

  @override
  ConsumerState<HandDetectionScreen> createState() => _HandDetectionScreenState();
}

class _HandDetectionScreenState extends ConsumerState<HandDetectionScreen> {
  HandDetectionResult? _latestResult;
  bool _isCameraReady = false;
  String? _errorMessage;
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  static const List<String> _fingerNames = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraService = ref.read(cameraServiceProvider);
      await cameraService.initialize();
      
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
    final engine = ref.read(handDetectionEngineProvider);
    
    cameraService.frameStream.listen((frame) {
      _updateFps();
      
      engine.detect(frame.data, width: frame.width, height: frame.height).then((result) {
        if (mounted) {
          setState(() {
            _latestResult = result as HandDetectionResult;
          });
        }
      }).catchError((e) {
        debugPrint('Hand detection error: $e');
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
        title: const Text('Hand Detection'),
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
                child: _buildHandOverlay(),
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
        _buildHandInfoPanel(),
      ],
    );
  }

  Widget _buildHandOverlay() {
    final result = _latestResult;
    if (result == null) {
      return const Center(
        child: Text(
          'No hand detected',
          style: TextStyle(color: Colors.white, fontSize: 16, shadows: [
            Shadow(blurRadius: 4, color: Colors.black),
          ]),
        ),
      );
    }

    // Draw hand landmarks if available
    if (result.landmarks != null && result.landmarks!.isNotEmpty) {
      return CustomPaint(
        painter: _HandLandmarkPainter(result.landmarks!),
        child: const SizedBox.expand(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHandInfoPanel() {
    final result = _latestResult;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result != null ? '${result.fingerCount} Finger${result.fingerCount != 1 ? 's' : ''}' : 'No hand detected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          if (result != null)
            ...List.generate(5, (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fingerNames[i],
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        result.fingerStates[i] ? 'OPEN' : 'CLOSED',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: result.fingerStates[i]
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 8),
          if (result != null)
            Text(
              'Total: ${result.fingerCount}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
    );
  }
}

/// Custom painter for hand landmarks
class _HandLandmarkPainter extends CustomPainter {
  final List<Offset> landmarks;

  _HandLandmarkPainter(this.landmarks);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections between landmarks (simplified hand skeleton)
    final connections = [
      // Thumb
      (0, 1), (1, 2), (2, 3), (3, 4),
      // Index
      (0, 5), (5, 6), (6, 7), (7, 8),
      // Middle
      (5, 9), (9, 10), (10, 11), (11, 12),
      // Ring
      (9, 13), (13, 14), (14, 15), (15, 16),
      // Pinky
      (13, 17), (17, 18), (18, 19), (19, 20),
      // Palm
      (0, 17),
    ];

    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    // Draw connections
    for (final (start, end) in connections) {
      if (start < landmarks.length && end < landmarks.length) {
        canvas.drawLine(
          Offset(landmarks[start].dx * size.width, landmarks[start].dy * size.height),
          Offset(landmarks[end].dx * size.width, landmarks[end].dy * size.height),
          linePaint,
        );
      }
    }

    // Draw landmark points
    for (final landmark in landmarks) {
      canvas.drawCircle(
        Offset(landmark.dx * size.width, landmark.dy * size.height),
        4,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HandLandmarkPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}