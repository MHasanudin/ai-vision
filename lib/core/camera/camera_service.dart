// Core camera abstraction

import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  final StreamController<CameraFrame> _frameController = StreamController<CameraFrame>.broadcast();
  bool _isProcessingFrame = false;
  int _frameSkipCounter = 0;
  int _frameSkipInterval = 2; // Process every 2nd frame by default

  /// Notifies listeners when the active camera controller changes (e.g. after switching cameras).
  final ValueNotifier<CameraController?> controllerNotifier = ValueNotifier(null);

  /// The active camera controller (used by preview widgets).
  CameraController? get controller => _controller;

  // Get available cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    return _cameras;
  }

  // Initialize camera
  Future<void> initialize({
    int cameraIndex = 0,
    ResolutionPreset resolutionPreset = ResolutionPreset.high,
    bool enableAudio = false,
    int frameSkipInterval = 2,
  }) async {
    _frameSkipInterval = frameSkipInterval;
    _cameras = await availableCameras();
    
    if (_cameras.isEmpty) {
      throw CameraException('No cameras available', 'No camera found on this device');
    }

    _selectedCameraIndex = cameraIndex.clamp(0, _cameras.length - 1);
    
    _controller = CameraController(
      _cameras[_selectedCameraIndex],
      resolutionPreset,
      enableAudio: enableAudio,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS 
          ? ImageFormatGroup.bgra8888 
          : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    controllerNotifier.value = _controller;
    
    // Start frame streaming
    await _startFrameStream();
  }

  // Start frame streaming
  Future<void> _startFrameStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    await _controller!.startImageStream((CameraImage image) {
      _processFrame(image);
    });
  }

  // Process camera frame
  void _processFrame(CameraImage image) {
    if (_isProcessingFrame) return;
    
    _frameSkipCounter++;
    if (_frameSkipCounter % _frameSkipInterval != 0) return;
    
    _isProcessingFrame = true;
    
    try {
      // Convert CameraImage to Uint8List (RGB format)
      final frame = _convertImageToFrame(image);
      if (frame != null) {
        _frameController.add(frame);
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  // Convert CameraImage to CameraFrame
  CameraFrame? _convertImageToFrame(CameraImage image) {
    try {
      // For YUV420 format (Android default)
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToRGB(image);
      }
      
      // For BGRA8888 format (iOS default)
      if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToRGB(image);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  // Convert YUV420 to RGB
  CameraFrame _convertYUV420ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    
    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;
    
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    
    final rgbBuffer = Uint8List(width * height * 3);
    int rgbIndex = 0;
    
    for (int y = 0; y < height; y++) {
      final yOffset = y * yRowStride;
      final uvOffset = (y ~/ 2) * uvRowStride;
      
      for (int x = 0; x < width; x++) {
        final yValue = yBuffer[yOffset + x];
        final uValue = uBuffer[uvOffset + (x ~/ 2) * uvPixelStride];
        final vValue = vBuffer[uvOffset + (x ~/ 2) * uvPixelStride];
        
        // YUV to RGB conversion
        int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round().clamp(0, 255);
        int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        rgbBuffer[rgbIndex++] = r;
        rgbBuffer[rgbIndex++] = g;
        rgbBuffer[rgbIndex++] = b;
      }
    }
    
    return CameraFrame(
      data: rgbBuffer,
      width: width,
      height: height,
    );
  }

  // Convert BGRA8888 to RGB
  CameraFrame _convertBGRA8888ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final bgraBuffer = image.planes[0].bytes;
    
    final rgbBuffer = Uint8List(width * height * 3);
    int rgbIndex = 0;
    
    for (int i = 0; i < bgraBuffer.length; i += 4) {
      // BGRA to RGB (skip alpha)
      rgbBuffer[rgbIndex++] = bgraBuffer[i + 2]; // R
      rgbBuffer[rgbIndex++] = bgraBuffer[i + 1]; // G
      rgbBuffer[rgbIndex++] = bgraBuffer[i];     // B
    }
    
    return CameraFrame(
      data: rgbBuffer,
      width: width,
      height: height,
    );
  }

  // Switch camera (front/rear)
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    
    final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _switchToCamera(newIndex);
  }

  // Switch to specific camera
  Future<void> _switchToCamera(int cameraIndex) async {
    if (cameraIndex < 0 || cameraIndex >= _cameras.length) return;
    if (cameraIndex == _selectedCameraIndex) return;
    
    await dispose();
    await initialize(cameraIndex: cameraIndex, frameSkipInterval: _frameSkipInterval);
  }

  // Set frame skip interval (for performance tuning)
  void setFrameSkipInterval(int interval) {
    _frameSkipInterval = interval.clamp(1, 10);
  }

  // Get frame stream
  Stream<CameraFrame> get frameStream => _frameController.stream;

  // Get current camera info
  CameraDescription? get currentCamera => 
      _selectedCameraIndex < _cameras.length ? _cameras[_selectedCameraIndex] : null;

  bool get isFrontCamera => currentCamera?.lensDirection == CameraLensDirection.front;
  bool get isRearCamera => currentCamera?.lensDirection == CameraLensDirection.back;

  // Get camera preview size
  Size? get previewSize => _controller?.value.previewSize;

  // Dispose resources
  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
    controllerNotifier.value = null;
    _isProcessingFrame = false;
  }
}

class CameraFrame {
  final Uint8List data; // RGB format
  final int width;
  final int height;

  CameraFrame({
    required this.data,
    required this.width,
    required this.height,
  });

  // Get aspect ratio
  double get aspectRatio => width / height;
}