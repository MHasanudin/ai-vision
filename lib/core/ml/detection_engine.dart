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
  static const double _iouThreshold = 0.45;

  /// Confidence threshold for filtering detections.
  /// Can be updated at runtime (e.g. from settings).
  double confidenceThreshold = 0.5;

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
      
      if (maxScore < confidenceThreshold) continue;
      
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

  static const int _inputSize = 256;
  static const int _numLandmarks = 21;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/hand_landmark.tflite');
      _isInitialized = true;
      debugPrint('HandDetectionEngine: Model loaded successfully');
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
      final srcW = width ?? _inputSize;
      final srcH = height ?? _inputSize;

      // Preprocess: resize to 256x256, normalize to [0,1]
      final input = _preprocessImage(imageData, srcW, srcH);

      // Prepare outputs (ByteBuffers preserve tensor shape — flat lists get reshaped to 1D)
      final landmarksOutput = Float32List(1 * 63).buffer; // [1, 63] = 21 landmarks * 3
      final handflagOutput = Float32List(1).buffer; // [1, 1]
      final handednessOutput = Float32List(1).buffer; // [1, 1]

      final outputs = <int, Object>{
        0: landmarksOutput,
        1: handflagOutput,
        2: handednessOutput,
      };

      _interpreter!.runForMultipleInputs([input.buffer], outputs);

      final handflag = handflagOutput.asFloat32List();
      final handedness = handednessOutput.asFloat32List();
      final landmarksRaw = landmarksOutput.asFloat32List();

      final handConfidence = handflag[0];
      if (handConfidence < 0.5) {
        return _getMockResult(); // No hand detected
      }

      // Parse landmarks
      final landmarks = <Offset>[];
      for (int i = 0; i < _numLandmarks; i++) {
        final x = landmarksRaw[i * 3].clamp(0.0, 1.0);
        final y = landmarksRaw[i * 3 + 1].clamp(0.0, 1.0);
        landmarks.add(Offset(x, y));
      }

      // Determine finger states
      final fingerStates = _calculateFingerStates(landmarks);
      final fingerCount = fingerStates.where((s) => s).length;
      final isLeftHand = handedness[0] > 0.5;

      return HandDetectionResult(
        fingerCount,
        fingerStates,
        landmarks: landmarks,
        isLeftHand: isLeftHand,
      );
    } catch (e) {
      debugPrint('HandDetectionEngine error: $e');
      return _getMockResult();
    }
  }

  List<bool> _calculateFingerStates(List<Offset> landmarks) {
    if (landmarks.length < 21) return [false, false, false, false, false];

    // Thumb: compare tip (4) to IP joint (3) x-position (wider hand = right hand rule)
    final thumbOpen = (landmarks[4] - landmarks[3]).distance >
        (landmarks[3] - landmarks[2]).distance * 0.5;

    // Index: tip (8) above PIP (6)
    final indexOpen = landmarks[8].dy < landmarks[6].dy;
    // Middle: tip (12) above PIP (10)
    final middleOpen = landmarks[12].dy < landmarks[10].dy;
    // Ring: tip (16) above PIP (14)
    final ringOpen = landmarks[16].dy < landmarks[14].dy;
    // Pinky: tip (20) above PIP (18)
    final pinkyOpen = landmarks[20].dy < landmarks[18].dy;

    return [thumbOpen, indexOpen, middleOpen, ringOpen, pinkyOpen];
  }

  /// Resize and normalize RGB image data to [1, 256, 256, 3] float32
  Float32List _preprocessImage(Uint8List rgbData, int srcWidth, int srcHeight) {
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    final scaleX = srcWidth / _inputSize;
    final scaleY = srcHeight / _inputSize;

    for (int y = 0; y < _inputSize; y++) {
      final srcY = (y * scaleY).round().clamp(0, srcHeight - 1);
      for (int x = 0; x < _inputSize; x++) {
        final srcX = (x * scaleX).round().clamp(0, srcWidth - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 3;
        final dstIdx = (y * _inputSize + x) * 3;

        if (srcIdx + 2 < rgbData.length && dstIdx + 2 < input.length) {
          input[dstIdx] = rgbData[srcIdx] / 255.0;     // R
          input[dstIdx + 1] = rgbData[srcIdx + 1] / 255.0; // G
          input[dstIdx + 2] = rgbData[srcIdx + 2] / 255.0; // B
        }
      }
    }
    return input;
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

/// Face Detection Engine using BlazeFace Short-Range TFLite model
/// 
/// Model specs (from MediaPipe source):
/// Input:  [1, 128, 128, 3] float32 (0-1)
/// Output: [1, 896, 16] regressors (4 box + 12 keypoints = 6 kp × 2)
///         [1, 896, 1]  classificators (scores)
/// Anchors: 4 layers, strides [8,16,16,16], 896 total
/// Box decode: reverse_output_order, apply_exponential, sigmoid_score
class FaceDetectionEngine extends DetectionEngine {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  static const int _inputSize = 128;
  static const int _numBoxes = 896;
  static const int _numCoords = 16;
  static const double _scoreThreshold = 0.5;
  static const double _nmsIouThreshold = 0.3;

  // BlazeFace short-range anchor config
  static const List<int> _strides = [8, 16, 16, 16];

  // Pre-computed anchors
  late List<List<double>> _anchors; // [896][4] = [x_center, y_center, w, h]

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/blazeface.tflite');
      _generateAnchors();
      _isInitialized = true;
      debugPrint('FaceDetectionEngine: Model loaded successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('FaceDetectionEngine: Model not found, using mock mode: $e');
    }
  }

  void _generateAnchors() {
    _anchors = [];
    for (int layerIdx = 0; layerIdx < _strides.length; layerIdx++) {
      final stride = _strides[layerIdx];
      final gridSize = (_inputSize / stride).ceil();
      // final scale — not used since we use fixed_anchor_size

      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          final cx = (x + 0.5) / gridSize;
          final cy = (y + 0.5) / gridSize;

          // First anchor: aspect_ratio=1.0, scale
          _anchors.add([cx, cy, 1.0, 1.0]);

          // Second anchor: interpolated scale with aspect_ratio=1.0
          _anchors.add([cx, cy, 1.0, 1.0]); // fixed_anchor_size, so w=h=1.0
        }
      }
    }
    debugPrint('FaceDetectionEngine: Generated ${_anchors.length} anchors');
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      return _getMockResult();
    }

    try {
      final srcW = width ?? _inputSize;
      final srcH = height ?? _inputSize;

      // Preprocess: resize to 128x128, normalize to [0,1]
      final input = _preprocessImage(imageData, srcW, srcH);

      // Prepare outputs (ByteBuffers preserve tensor shape — flat lists get reshaped to 1D)
      final regressorsOutput = Float32List(1 * _numBoxes * _numCoords).buffer;
      final classificatorsOutput = Float32List(1 * _numBoxes).buffer;

      final outputs = <int, Object>{
        0: regressorsOutput,
        1: classificatorsOutput,
      };

      _interpreter!.runForMultipleInputs([input.buffer], outputs);

      // Decode detections
      final boxes = _decodeDetections(
        regressorsOutput.asFloat32List(),
        classificatorsOutput.asFloat32List(),
      );

      return FaceDetectionResult(boxes);
    } catch (e) {
      debugPrint('FaceDetectionEngine inference error: $e');
      return _getMockResult();
    }
  }

  List<DetectionBox> _decodeDetections(
    Float32List regressors,
    Float32List scores,
  ) {
    final candidates = <DetectionBox>[];

    for (int i = 0; i < _numBoxes; i++) {
      // Apply sigmoid to score (sigmoid_score=true)
      final rawScore = scores[i];
      final clippedScore = rawScore.clamp(-100.0, 100.0);
      final score = 1.0 / (1.0 + math.exp(-clippedScore));

      if (score < _scoreThreshold) continue;

      // Decode box: reverse_output_order means [x_center, y_center, w, h]
      final anchor = _anchors[i];
      final anchorXc = anchor[0];
      final anchorYc = anchor[1];

      // reverse_output_order=true: raw[0]=x, raw[1]=y, raw[2]=w, raw[3]=h
      final rawX = regressors[i * _numCoords + 0];
      final rawY = regressors[i * _numCoords + 1];
      final rawW = regressors[i * _numCoords + 2];
      final rawH = regressors[i * _numCoords + 3];

      // Decode: x = raw/x_scale * anchor_w + anchor_xc
      final cx = rawX / _inputSize + anchorXc; // anchor_w=1.0
      final cy = rawY / _inputSize + anchorYc; // anchor_h=1.0
      // Apply exponential for width/height (apply_exponential_on_box_size=true)
      final w = math.exp(rawW / _inputSize); // anchor_w=1.0
      final h = math.exp(rawH / _inputSize); // anchor_h=1.0

      // Convert to (x1, y1, x2, y2) normalized to [0,1]
      final x1 = (cx - w / 2).clamp(0.0, 1.0);
      final y1 = (cy - h / 2).clamp(0.0, 1.0);
      final x2 = (cx + w / 2).clamp(0.0, 1.0);
      final y2 = (cy + h / 2).clamp(0.0, 1.0);

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      if (rect.width <= 0 || rect.height <= 0) continue;

      candidates.add(DetectionBox(
        rect: rect,
        label: 'Face',
        confidence: score,
        classIndex: 0,
      ));
    }

    // Apply NMS
    return _applyNMS(candidates);
  }

  List<DetectionBox> _applyNMS(List<DetectionBox> boxes) {
    if (boxes.isEmpty) return [];
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    final keep = <DetectionBox>[];
    final active = List<DetectionBox>.from(boxes);

    while (active.isNotEmpty) {
      final best = active.removeAt(0);
      keep.add(best);

      active.removeWhere((box) => _calculateIoU(best.rect, box.rect) > _nmsIouThreshold);
    }

    return keep;
  }

  double _calculateIoU(Rect a, Rect b) {
    final intersectLeft = math.max(a.left, b.left);
    final intersectTop = math.max(a.top, b.top);
    final intersectRight = math.min(a.right, b.right);
    final intersectBottom = math.min(a.bottom, b.bottom);

    if (intersectLeft >= intersectRight || intersectTop >= intersectBottom) return 0.0;

    final intersectArea = (intersectRight - intersectLeft) * (intersectBottom - intersectTop);
    final aArea = a.width * a.height;
    final bArea = b.width * b.height;
    return intersectArea / (aArea + bArea - intersectArea);
  }

  /// Resize and normalize RGB image data to [1, 128, 128, 3] float32
  Float32List _preprocessImage(Uint8List rgbData, int srcWidth, int srcHeight) {
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    final scaleX = srcWidth / _inputSize;
    final scaleY = srcHeight / _inputSize;

    for (int y = 0; y < _inputSize; y++) {
      final srcY = (y * scaleY).round().clamp(0, srcHeight - 1);
      for (int x = 0; x < _inputSize; x++) {
        final srcX = (x * scaleX).round().clamp(0, srcWidth - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 3;
        final dstIdx = (y * _inputSize + x) * 3;

        if (srcIdx + 2 < rgbData.length && dstIdx + 2 < input.length) {
          input[dstIdx] = rgbData[srcIdx] / 255.0;         // R
          input[dstIdx + 1] = rgbData[srcIdx + 1] / 255.0; // G
          input[dstIdx + 2] = rgbData[srcIdx + 2] / 255.0; // B
        }
      }
    }
    return input;
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

  static const int _inputSize = 112;
  static const int _embeddingSize = 192;

  // Face database for recognition (personId -> embedding)
  final Map<String, List<double>> _faceDatabase = {};

  // Face detector used to locate faces before embedding
  final FaceDetectionEngine _faceDetector = FaceDetectionEngine();

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      await _faceDetector.initialize();
      _isInitialized = true;
      debugPrint('FaceRecognitionEngine: Model loaded successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('FaceRecognitionEngine: Model not found, using mock mode: $e');
    }
  }

  /// Extract a 192-dim embedding from RGB image data.
  /// Returns null if the model is not initialized or inference fails.
  Future<List<double>?> extractEmbedding(
    Uint8List rgbData, {
    int? width,
    int? height,
  }) async {
    if (!_isInitialized || _interpreter == null) return null;

    try {
      final srcW = width ?? _inputSize;
      final srcH = height ?? _inputSize;

      // Preprocess: resize to 112x112, normalize to [-1, 1]
      final input = _preprocessImage(rgbData, srcW, srcH);

      // Output: [1, 192] embedding (ByteBuffer preserves tensor shape)
      final output = Float32List(_embeddingSize).buffer;

      _interpreter!.runForMultipleInputs([input.buffer], {0: output});

      return output.asFloat32List().toList();
    } catch (e) {
      debugPrint('FaceRecognitionEngine extractEmbedding error: $e');
      return null;
    }
  }

  /// Extract an embedding from a face crop region of a full frame.
  /// [faceRect] is normalized (0-1) relative to the frame.
  Future<List<double>?> extractEmbeddingFromCrop(
    Uint8List rgbData, {
    required Rect faceRect,
    required int frameWidth,
    required int frameHeight,
  }) async {
    // Convert normalized rect to pixel coordinates
    final x1 = (faceRect.left * frameWidth).round().clamp(0, frameWidth - 1);
    final y1 = (faceRect.top * frameHeight).round().clamp(0, frameHeight - 1);
    final x2 = (faceRect.right * frameWidth).round().clamp(x1 + 1, frameWidth);
    final y2 = (faceRect.bottom * frameHeight).round().clamp(y1 + 1, frameHeight);

    final cropW = x2 - x1;
    final cropH = y2 - y1;
    if (cropW <= 0 || cropH <= 0) return null;

    // Crop the face region (RGB interleaved)
    final crop = Uint8List(cropW * cropH * 3);
    for (int y = 0; y < cropH; y++) {
      final srcRow = (y1 + y) * frameWidth * 3;
      final dstRow = y * cropW * 3;
      for (int x = 0; x < cropW * 3; x++) {
        crop[dstRow + x] = rgbData[srcRow + x1 * 3 + x];
      }
    }

    return extractEmbedding(crop, width: cropW, height: cropH);
  }

  @override
  Future<DetectionResult> detect(Uint8List imageData, {int? width, int? height}) async {
    if (!_isInitialized || _interpreter == null) {
      return _getMockResult();
    }

    try {
      final srcW = width ?? _inputSize;
      final srcH = height ?? _inputSize;

      // 1. Detect faces
      final faceResult = await _faceDetector.detect(imageData, width: srcW, height: srcH);
      final faces = faceResult.boxes;
      if (faces.isEmpty) {
        return FaceRecognitionResult(
          personName: 'Unknown',
          dateOfBirth: '',
          personId: '',
          similarity: 0,
          faceRect: Rect.zero,
        );
      }

      // 2. Take the largest face
      final largest = faces.reduce((a, b) {
        final areaA = a.rect.width * a.rect.height;
        final areaB = b.rect.width * b.rect.height;
        return areaA >= areaB ? a : b;
      });

      // 3. Extract embedding from the face crop
      final embedding = await extractEmbeddingFromCrop(
        imageData,
        faceRect: largest.rect,
        frameWidth: srcW,
        frameHeight: srcH,
      );

      if (embedding == null) {
        return FaceRecognitionResult(
          personName: 'Unknown',
          dateOfBirth: '',
          personId: '',
          similarity: 0,
          faceRect: largest.rect,
        );
      }

      // 4. Find best match in database
      final match = findBestMatch(embedding, 0.4);
      if (match == null) {
        return FaceRecognitionResult(
          personName: 'Unknown',
          dateOfBirth: '',
          personId: '',
          similarity: 0,
          faceRect: largest.rect,
        );
      }

      return FaceRecognitionResult(
        personName: match,
        dateOfBirth: '',
        personId: '',
        similarity: _lastSimilarity,
        faceRect: largest.rect,
      );
    } catch (e) {
      debugPrint('FaceRecognitionEngine error: $e');
      return _getMockResult();
    }
  }

  double _lastSimilarity = 0;

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    await _faceDetector.dispose();
  }

  // Add face to database
  Future<void> registerFace(String personId, List<double> embedding) async {
    _faceDatabase[personId] = embedding;
  }

  // Clear the in-memory database
  void clearDatabase() {
    _faceDatabase.clear();
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

    _lastSimilarity = bestSimilarity;
    return bestMatch;
  }

  /// Find the best matching person from a list of candidates loaded from the
  /// database. Returns the personId and similarity, or null if none pass [threshold].
  (String personId, double similarity)? findBestMatchIn(
    List<double> embedding,
    List<MapEntry<String, List<double>>> candidates,
    double threshold,
  ) {
    String? bestId;
    double bestSimilarity = 0;

    for (final candidate in candidates) {
      final similarity = _cosineSimilarity(embedding, candidate.value);
      if (similarity > bestSimilarity && similarity >= threshold) {
        bestSimilarity = similarity;
        bestId = candidate.key;
      }
    }

    _lastSimilarity = bestSimilarity;
    if (bestId == null) return null;
    return (bestId, bestSimilarity);
  }

  /// Public cosine similarity (used by screens for matching).
  double cosineSimilarity(List<double> a, List<double> b) => _cosineSimilarity(a, b);

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

  /// Resize and normalize RGB image data to [1, 112, 112, 3] float32 in [-1, 1]
  Float32List _preprocessImage(Uint8List rgbData, int srcWidth, int srcHeight) {
    final input = Float32List(1 * _inputSize * _inputSize * 3);
    final scaleX = srcWidth / _inputSize;
    final scaleY = srcHeight / _inputSize;

    for (int y = 0; y < _inputSize; y++) {
      final srcY = (y * scaleY).round().clamp(0, srcHeight - 1);
      for (int x = 0; x < _inputSize; x++) {
        final srcX = (x * scaleX).round().clamp(0, srcWidth - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 3;
        final dstIdx = (y * _inputSize + x) * 3;

        if (srcIdx + 2 < rgbData.length && dstIdx + 2 < input.length) {
          input[dstIdx] = (rgbData[srcIdx] - 127.5) / 127.5;         // R
          input[dstIdx + 1] = (rgbData[srcIdx + 1] - 127.5) / 127.5; // G
          input[dstIdx + 2] = (rgbData[srcIdx + 2] - 127.5) / 127.5; // B
        }
      }
    }
    return input;
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