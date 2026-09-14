import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_vision/core/ml/detection_engine.dart';
import 'package:ai_vision/core/camera/camera_providers.dart';

/// Provider for ObjectDetectionEngine
final objectDetectionEngineProvider = Provider<ObjectDetectionEngine>((ref) {
  final engine = ObjectDetectionEngine();
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Provider for HandDetectionEngine
final handDetectionEngineProvider = Provider<HandDetectionEngine>((ref) {
  final engine = HandDetectionEngine();
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Provider for FaceDetectionEngine
final faceDetectionEngineProvider = Provider<FaceDetectionEngine>((ref) {
  final engine = FaceDetectionEngine();
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Provider for FaceRecognitionEngine
final faceRecognitionEngineProvider = Provider<FaceRecognitionEngine>((ref) {
  final engine = FaceRecognitionEngine();
  
  ref.onDispose(() {
    engine.dispose();
  });
  
  return engine;
});

/// Provider for initializing all engines
final mlEnginesInitializedProvider = FutureProvider<void>((ref) async {
  final objectEngine = ref.watch(objectDetectionEngineProvider);
  final handEngine = ref.watch(handDetectionEngineProvider);
  final faceEngine = ref.watch(faceDetectionEngineProvider);
  final faceRecEngine = ref.watch(faceRecognitionEngineProvider);
  
  await Future.wait([
    objectEngine.initialize(),
    handEngine.initialize(),
    faceEngine.initialize(),
    faceRecEngine.initialize(),
  ]);
});

/// Detection mode enum
enum DetectionMode {
  object,
  hand,
  face,
  faceRecognition,
}

/// Current detection mode provider
final detectionModeProvider = StateProvider<DetectionMode>((ref) => DetectionMode.object);

/// Confidence threshold for object detection
final objectConfidenceThresholdProvider = StateProvider<double>((ref) => 0.5);

/// Face recognition threshold
final faceRecognitionThresholdProvider = StateProvider<double>((ref) => 0.7);

/// Inference FPS target
final inferenceFpsProvider = StateProvider<int>((ref) => 15);

/// Latest detection results
final objectDetectionResultProvider = StreamProvider.autoDispose<ObjectDetectionResult>((ref) async* {
  final cameraService = ref.watch(cameraServiceProvider);
  final engine = ref.watch(objectDetectionEngineProvider);
  
  await for (final frame in cameraService.frameStream) {
    final result = await engine.detect(frame.data, width: frame.width, height: frame.height);
    yield result as ObjectDetectionResult;
  }
});

final handDetectionResultProvider = StreamProvider.autoDispose<HandDetectionResult>((ref) async* {
  final cameraService = ref.watch(cameraServiceProvider);
  final engine = ref.watch(handDetectionEngineProvider);
  
  await for (final frame in cameraService.frameStream) {
    final result = await engine.detect(frame.data, width: frame.width, height: frame.height);
    yield result as HandDetectionResult;
  }
});

final faceDetectionResultProvider = StreamProvider.autoDispose<FaceDetectionResult>((ref) async* {
  final cameraService = ref.watch(cameraServiceProvider);
  final engine = ref.watch(faceDetectionEngineProvider);
  
  await for (final frame in cameraService.frameStream) {
    final result = await engine.detect(frame.data, width: frame.width, height: frame.height);
    yield result as FaceDetectionResult;
  }
});

final faceRecognitionResultProvider = StreamProvider.autoDispose<FaceRecognitionResult>((ref) async* {
  final cameraService = ref.watch(cameraServiceProvider);
  final engine = ref.watch(faceRecognitionEngineProvider);
  
  await for (final frame in cameraService.frameStream) {
    final result = await engine.detect(frame.data, width: frame.width, height: frame.height);
    yield result as FaceRecognitionResult;
  }
});