// Core camera abstraction
package: ai_vision.core.camera

class CameraService {
  // TODO: Implement camera initialization, frame processing, etc.
  Future<void> initialize() async {
    // Initialize camera
  }

  Future<void> dispose() async {
    // Dispose camera resources
  }

  // Stream of camera frames
  Stream<CameraFrame> get frameStream => const Stream.empty();
}

class CameraFrame {
  final Uint8List data;
  final int width;
  final int height;

  CameraFrame({
    required this.data,
    required this.width,
    required this.height,
  });
}