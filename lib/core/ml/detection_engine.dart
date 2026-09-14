// Core ML abstraction

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class DetectionEngine {
  Future<void> initialize();
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height});
  Future<void> dispose();
  bool get isInitialized;
}

abstract class DetectionResult {
  String get displayText;
  List<DetectionBox> get boxes;
}

// Detection box for bounding box visualization
class DetectionBox {
  final Rect rect; // Normalized coordinates (0-1)
  final String label;
  final double confidence;
  final int classIndex;

  DetectionBox({
    required this.rect,
    required this.label,
    required this.confidence,
    required this.classIndex,
  });
}

// Specific detection results
class ObjectDetectionResult extends DetectionResult {
  @override
  final List<DetectionBox> boxes;
  final int inferenceTimeMs;

  ObjectDetectionResult(this.boxes, {this.inferenceTimeMs = 0});

  @override
  String get displayText {
    if (boxes.isEmpty) return 'No objects detected';
    return '${boxes.length} object(s) detected';
  }
}

class HandDetectionResult extends DetectionResult {
  final int fingerCount;
  final List<bool> fingerStates; // thumb, index, middle, ring, pinky
  final List<Offset>? landmarks; // 21 hand landmarks (normalized)
  final bool isLeftHand;

  HandDetectionResult(
    this.fingerCount,
    this.fingerStates, {
    this.landmarks,
    this.isLeftHand = false,
  });

  @override
  List<DetectionBox> get boxes => [];

  @override
  String get displayText => '$fingerCount Finger${fingerCount != 1 ? 's' : ''}';
}

class FaceDetectionResult extends DetectionResult {
  @override
  final List<DetectionBox> boxes;
  final List<List<Offset>>? landmarks; // Face landmarks per face

  FaceDetectionResult(this.boxes, {this.landmarks});

  @override
  String get displayText => boxes.isEmpty ? 'No Face Detected' : '${boxes.length} Face(s) Detected';
}

class FaceRecognitionResult extends DetectionResult {
  final String personName;
  final String dateOfBirth;
  final String personId;
  final double similarity;
  final Rect faceRect;

  FaceRecognitionResult({
    required this.personName,
    required this.dateOfBirth,
    required this.personId,
    required this.similarity,
    required this.faceRect,
  });

  @override
  List<DetectionBox> get boxes => [
    DetectionBox(
      rect: faceRect,
      label: personName,
      confidence: similarity,
      classIndex: 0,
    ),
  ];

  @override
  String get displayText => '''
$personName
$dateOfBirth
$personId
Match: ${(similarity * 100).toStringAsFixed(1)}%
''';
}

// COCO class labels (80 classes)
const List<String> _cocoLabels = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
  'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
  'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
  'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
  'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket',
  'bottle', 'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple',
  'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake',
  'chair', 'couch', 'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop',
  'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink',
  'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier',
  'toothbrush',
];

/// Object Detection Engine using YOLOv8 TFLite model
class ObjectDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  
  // Model configuration
  static const int _inputSize = 640;
  static const int _numClasses = 80;
  static const int _maxDetections = 100;
  
  // Preprocessing
  static const double _confidenceThreshold = 0.5;
  static const double _iouThreshold = 0.45;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n.tflite');
      _isInitialized = true;
    } catch (e) {
      // Model not found, use mock mode
      _isInitialized = false;
      debugPrint('ObjectDetectionEngine: Model not found, using mock mode: $e');
    }
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      // Return mock result for testing
      return _getMockResult();
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      // Preprocess image
      final input = _preprocessImage(imageData, width ?? _inputSize, height ?? _inputSize);
      
      // Run inference
      final output = _runInference(input);
      
      // Postprocess results
      final boxes = _postprocess(output, width ?? _inputSize, height ?? _inputSize);
      
      stopwatch.stop();
      
      return ObjectDetectionResult(boxes, inferenceTimeMs: stopwatch.elapsedMilliseconds);
    } catch (e) {
      debugPrint('ObjectDetectionEngine error: $e');
      return _getMockResult();
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  // Preprocess image: letterbox resize to 640x640, normalize to [0,1]
  Float32List _preprocessImage(Uint8List imageData, int srcWidth, int srcHeight) {
    final input = Float32List(_inputSize * _inputSize * 3);
    
    // Calculate letterbox scaling
    final scale = math.min(_inputSize / srcWidth, _inputSize / srcHeight);
    final newWidth = (srcWidth * scale).round();
    final newHeight = (srcHeight * scale).round();
    final padX = (_inputSize - newWidth) ~/ 2;
    final padY = (_inputSize - newHeight) ~/ 2;
    
    // Resize and normalize (simple nearest neighbor for now)
    // In production, use image package for better quality
    for (int y = 0; y < newHeight; y++) {
      for (int x = 0; x < newWidth; x++) {
        final srcX = (x / scale).round().clamp(0, srcWidth - 1);
        final srcY = (y / scale).round().clamp(0, srcHeight - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 3;
        
        final dstX = x + padX;
        final dstY = y + padY;
        final dstIdx = (dstY * _inputSize + dstX) * 3;
        
        if (dstIdx + 2 < input.length && srcIdx + 2 < imageData.length) {
          input[dstIdx] = imageData[srcIdx] / 255.0;     // R
          input[dstIdx + 1] = imageData[srcIdx + 1] / 255.0; // G
          input[dstIdx + 2] = imageData[srcIdx + 2] / 255.0; // B
        }
      }
    }
    
    // Fill padding with 0.5 (gray)
    // Top/bottom padding
    for (int y = 0; y < padY; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final idx = (y * _inputSize + x) * 3;
        input[idx] = 0.5;
        input[idx + 1] = 0.5;
        input[idx + 2] = 0.5;
        // Bottom
        final bottomY = _inputSize - 1 - y;
        final bottomIdx = (bottomY * _inputSize + x) * 3;
        input[bottomIdx] = 0.5;
        input[bottomIdx + 1] = 0.5;
        input[bottomIdx + 2] = 0.5;
      }
    }
    // Left/right padding
    for (int y = padY; y < _inputSize - padY; y++) {
      for (int x = 0; x < padX; x++) {
        final idx = (y * _inputSize + x) * 3;
        input[idx] = 0.5;
        input[idx + 1] = 0.5;
        input[idx + 2] = 0.5;
        // Right
        final rightX = _inputSize - 1 - x;
        final rightIdx = (y * _inputSize + rightX) * 3;
        input[rightIdx] = 0.5;
        input[rightIdx + 1] = 0.5;
        input[rightIdx + 2] = 0.5;
      }
    }
    
    return input;
  }

  // Run inference
  List<List<double>> _runInference(Float32List input) {
    // YOLOv8 output shape: [1, 84, 8400] where 84 = 4 (box) + 80 (classes)
    final output = List.filled(84 * 8400, 0.0).reshape([1, 84, 8400]);
    
    _interpreter!.run(input.buffer, output);
    
    // Convert to List<List<double>> for easier processing
    return output[0].map((row) => row.cast<double>()).toList();
  }

  // Postprocess: decode boxes, apply NMS, filter by confidence
  List<DetectionBox> _postprocess(List<List<double>> output, int origWidth, int origHeight) {
    final boxes = <DetectionBox>[];
    
    // Output format: [84, 8400] -> 8400 detections, each with 84 values
    // First 4: cx, cy, w, h (normalized to input size)
    // Next 80: class scores
    
    for (int i = 0; i < 8400; i++) {
      // Find max class score
      double maxScore = 0;
      int maxClass = 0;
      
      for (int c = 0; c < _numClasses; c++) {
        final score = output[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          maxClass = c;
        }
      }
      
      if (maxScore < _confidenceThreshold) continue;
      
      // Decode box (cx, cy, w, h) -> (x1, y1, x2, y2) normalized to input size
      final cx = output[0][i];
      final cy = output[1][i];
      final w = output[2][i];
      final h = output[3][i];
      
      // Convert to normalized coordinates (0-1) relative to original image
      // Account for letterbox padding
      final scale = math.min(_inputSize / origWidth, _inputSize / origHeight);
      final padX = (_inputSize - origWidth * scale) / 2;
      final padY = (_inputSize - origHeight * scale) / 2;
      
      final x1 = ((cx - w / 2) - padX) / scale / origWidth;
      final y1 = ((cy - h / 2) - padY) / scale / origHeight;
      final x2 = ((cx + w / 2) - padX) / scale / origWidth;
      final y2 = ((cy + h / 2) - padY) / scale / origHeight;
      
      // Clamp to [0, 1]
      final rect = Rect.fromLTRB(
        x1.clamp(0.0, 1.0),
        y1.clamp(0.0, 1.0),
        x2.clamp(0.0, 1.0),
        y2.clamp(0.0, 1.0),
      );
      
      // Skip invalid boxes
      if (rect.width <= 0 || rect.height <= 0) continue;
      
      boxes.add(DetectionBox(
        rect: rect,
        label: _cocoLabels[maxClass],
        confidence: maxScore,
        classIndex: maxClass,
      ));
    }
    
    // Apply Non-Maximum Suppression
    return _applyNMS(boxes);
  }

  // Non-Maximum Suppression
  List<DetectionBox> _applyNMS(List<DetectionBox> boxes) {
    if (boxes.isEmpty) return [];
    
    // Sort by confidence descending
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final keep = <DetectionBox>[];
    
    while (boxes.isNotEmpty) {
      final best = boxes.removeAt(0);
      keep.add(best);
      
      if (keep.length >= _maxDetections) break;
      
      // Remove boxes with high IoU
      boxes.removeWhere((box) => _calculateIoU(best.rect, box.rect) > _iouThreshold);
    }
    
    return keep;
  }

  // Calculate IoU between two normalized rects
  double _calculateIoU(Rect a, Rect b) {
    final intersectLeft = math.max(a.left, b.left);
    final intersectTop = math.max(a.top, b.top);
    final intersectRight = math.min(a.right, b.right);
    final intersectBottom = math.min(a.bottom, b.bottom);
    
    if (intersectLeft >= intersectRight || intersectTop >= intersectBottom) {
      return 0.0;
    }
    
    final intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final aArea = a.width * a.height;
    final bArea = b.width * b.height;
    final unionArea = aArea + bArea - intersectArea;
    
    return intersectArea / unionArea;
  }

  // Mock result for testing without model
  ObjectDetectionResult _getMockResult() {
    return ObjectDetectionResult([
      DetectionBox(
        rect: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.5),
        label: 'Cell Phone',
        confidence: 0.96,
        classIndex: 67,
      ),
      DetectionBox(
        rect: const Rect.fromLTWH(0.1, 0.4, 0.3, 0.3),
        label: 'Laptop',
        confidence: 0.91,
        classIndex: 63,
      ),
    ]);
  }
}

/// Hand Detection Engine using MediaPipe Hand Landmark TFLite model
class HandDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/hand_landmark.tflite');
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('HandDetectionEngine: Model not found, using mock mode: $e');
    }
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      return _getMockResult();
    }

    try {
      // TODO: Implement actual hand landmark detection
      // Preprocess: resize to 256x256, normalize
      // Run inference
      // Postprocess: extract 21 landmarks, calculate finger states
      return _getMockResult();
    } catch (e) {
      debugPrint('HandDetectionEngine error: $e');
      return _getMockResult();
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  HandDetectionResult _getMockResult() {
    return HandDetectionResult(
      2,
      [false, true, true, false, false],
      landmarks: List.generate(21, (i) => Offset(i % 5 * 0.1, i ~/ 5 * 0.1)),
      isLeftHand: false,
    );
  }
}

/// Face Detection Engine using BlazeFace TFLite model
class FaceDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/blazeface.tflite');
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('FaceDetectionEngine: Model not found, using mock mode: $e');
    }
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      return _getMockResult();
    }

    try {
      // TODO: Implement actual face detection
      // Preprocess: resize to 128x128, normalize
      // Run inference
      // Postprocess: decode boxes and keypoints
      return _getMockResult();
    } catch (e) {
      debugPrint('FaceDetectionEngine error: $e');
      return _getMockResult();
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  FaceDetectionResult _getMockResult() {
    return FaceDetectionResult([
      DetectionBox(
        rect: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.5),
        label: 'Face',
        confidence: 0.95,
        classIndex: 0,
      ),
    ]);
  }
}

/// Face Recognition Engine using MobileFaceNet TFLite model
class FaceRecognitionEngine extends DetectionEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  
  // Face database for recognition (in production, use proper database)
  final Map<String, List<double>> _faceDatabase = {};

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      debugPrint('FaceRecognitionEngine: Model not found, using mock mode: $e');
    }
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      return _getMockResult();
    }

    try {
      // TODO: Implement actual face recognition
      // 1. Detect face (use FaceDetectionEngine)
      // 2. Align and crop face to 112x112
      // 3. Generate embedding
      // 4. Compare with database using cosine similarity
      return _getMockResult();
    } catch (e) {
      debugPrint('FaceRecognitionEngine error: $e');
      return _getMockResult();
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  // Add face to database
  Future<void> registerFace(String personId, List<double> embedding) async {
    _faceDatabase[personId] = embedding;
  }

  // Find best match
  String? findBestMatch(List<double> embedding, double threshold) {
    String? bestMatch;
    double bestSimilarity = 0;
    
    for (final entry in _faceDatabase.entries) {
      final similarity = _cosineSimilarity(embedding, entry.value);
      if (similarity > bestSimilarity && similarity >= threshold) {
        bestSimilarity = similarity;
        bestMatch = entry.key;
      }
    }
    
    return bestMatch;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  FaceRecognitionResult _getMockResult() {
    return FaceRecognitionResult(
      personName: 'Budi Santoso',
      dateOfBirth: '12 March 1998',
      personId: 'EMP-001',
      similarity: 0.948,
      faceRect: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.5),
    );
  }
}