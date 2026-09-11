// Core ML abstraction
package: ai_vision.core.ml

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class DetectionEngine {
  Future<DetectionResult> detect(Uint8List imageData);
}

abstract class DetectionResult {
  String get displayText;
}

// Specific detection results
class ObjectDetectionResult extends DetectionResult {
  final String label;
  final double confidence;

  ObjectDetectionResult(this.label, this.confidence);

  @override
  String get displayText => '$label\n${(confidence * 100).toStringAsFixed(1)}%';
}

class HandDetectionResult extends DetectionResult {
  final int fingerCount;
  final List<bool> fingerStates; // thumb, index, middle, ring, pinky

  HandDetectionResult(this.fingerCount, this.fingerStates);

  @override
  String get displayText => '$fingerCount Fingers';
}

class FaceDetectionResult extends DetectionResult {
  final Rect? faceRect; // bounding box of detected face

  FaceDetectionResult(this.faceRect);

  @override
  String get displayText => faceRect != null ? 'Face Detected' : 'No Face Detected';
}

class FaceRecognitionResult extends DetectionResult {
  final String personName;
  final String dateOfBirth;
  final String personId;
  final double similarity;

  FaceRecognitionResult(this.personName, this.dateOfBirth, this.personId, this.similarity);

  @override
  String get displayText => '''
$personName
$dateOfBirth
$personId
Match: ${(similarity * 100).toStringAsFixed(1)}%
''';
}

// Specific detection engines (stubs)
class ObjectDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;

  ObjectDetectionEngine() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    // TODO: Load actual TFLite model for object detection
    // _interpreter = await Interpreter.fromAsset('assets/models/object_detection.tflite');
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData) async {
    // TODO: Implement actual object detection using TensorFlow Lite
    // For now, return a mock result
    return ObjectDetectionResult('Cell Phone', 0.96);
  }
}

class HandDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;

  HandDetectionEngine() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    // TODO: Load actual TFLite model for hand detection
    // _interpreter = await Interpreter.fromAsset('assets/models/hand_detection.tflite');
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData) async {
    // TODO: Implement actual hand detection using TensorFlow Lite
    // For now, return a mock result (2 fingers: index and middle open)
    return HandDetectionResult(2, [false, true, true, false, false]);
  }
}

class FaceDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;

  FaceDetectionEngine() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    // TODO: Load actual TFLite model for face detection
    // _interpreter = await Interpreter.fromAsset('assets/models/face_detection.tflite');
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData) async {
    // TODO: Implement actual face detection using TensorFlow Lite
    // For now, return a mock result with a face in the center
    return FaceDetectionResult(const Rect.fromLTWH(100, 100, 200, 200));
  }
}

class FaceRecognitionEngine extends DetectionEngine {
  Interpreter? _interpreter;

  FaceRecognitionEngine() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    // TODO: Load actual TFLite model for face recognition/embedding
    // _interpreter = await Interpreter.fromAsset('assets/models/face_recognition.tflite');
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData) async {
    // TODO: Implement actual face recognition using TensorFlow Lite
    // For now, return a mock result
    return FaceRecognitionResult(
      'Budi Santoso',
      '12 March 1998',
      'EMP-001',
      0.948,
    );
  }
}