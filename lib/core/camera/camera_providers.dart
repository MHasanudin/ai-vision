import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_vision/core/camera/camera_service.dart';

/// Provider for CameraService
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  
  // Dispose when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for camera initialization state
final cameraInitializedProvider = FutureProvider<void>((ref) async {
  final cameraService = ref.watch(cameraServiceProvider);
  await cameraService.initialize();
});

/// Provider for available cameras
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  final cameraService = ref.watch(cameraServiceProvider);
  return await cameraService.getAvailableCameras();
});

/// Provider for camera frame stream
final cameraFrameStreamProvider = StreamProvider<CameraFrame>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.frameStream;
});

/// Provider for current camera info
final currentCameraProvider = Provider<CameraDescription?>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.currentCamera;
});

/// Provider for camera facing direction
final isFrontCameraProvider = Provider<bool>((ref) {
  final cameraService = ref.watch(cameraServiceProvider);
  return cameraService.isFrontCamera;
});

/// Provider for frame skip interval (performance tuning)
final frameSkipIntervalProvider = StateProvider<int>((ref) => 2);