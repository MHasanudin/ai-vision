# AI Vision - TFLite Models

This directory should contain the following TensorFlow Lite models for on-device inference.

## Required Models

### 1. Object Detection - YOLOv8n (COCO)
- **File**: `yolov8n.tflite`
- **Input**: 640x640 RGB (1, 640, 640, 3) - float32 or uint8
- **Output**: Detection boxes, classes, scores
- **Classes**: 80 COCO classes (person, bicycle, car, bottle, chair, laptop, cell phone, etc.)
- **Source**: https://github.com/ultralytics/ultralytics (export with `yolo export format=tflite model=yolov8n.pt`)

### 2. Face Detection - BlazeFace
- **File**: `blazeface.tflite`
- **Input**: 128x128 RGB (1, 128, 128, 3) - float32
- **Output**: Face bounding boxes, keypoints (6 landmarks), scores
- **Source**: https://github.com/google/mediapipe (BlazeFace model)

### 3. Face Embedding - MobileFaceNet
- **File**: `mobilefacenet.tflite`
- **Input**: 112x112 RGB (1, 112, 112, 3) - float32, normalized to [-1, 1]
- **Output**: 192-dim or 512-dim embedding vector
- **Source**: https://github.com/deepinsight/insightface (MobileFaceNet)

### 4. Hand Landmark Detection - MediaPipe Hand
- **File**: `hand_landmark.tflite`
- **Input**: 256x256 RGB (1, 256, 256, 3) - float32
- **Output**: 21 hand landmarks (x, y, z), handedness score
- **Source**: https://github.com/google/mediapipe (Hand Landmark model)

## Model Optimization

For better performance on mobile:
1. **Quantization**: Use post-training quantization (int8) or quantization-aware training
2. **Metadata**: Add TFLite metadata for easier integration
3. **Delegate**: Consider GPU delegate for faster inference

## Download Instructions

```bash
# Object Detection (YOLOv8n)
# 1. Install ultralytics: pip install ultralytics
# 2. Export: yolo export format=tflite model=yolov8n.pt imgsz=640
# 3. Copy yolov8n.tflite to this directory

# Face Detection (BlazeFace)
# Download from MediaPipe or TensorFlow Hub

# Face Embedding (MobileFaceNet)
# Convert from PyTorch/ONNX to TFLite

# Hand Landmark (MediaPipe Hand)
# Download from MediaPipe or TensorFlow Hub
```

## Model Input/Output Specifications

### YOLOv8n (Object Detection)
```
Input:  [1, 640, 640, 3] float32 (0-1) or uint8 (0-255)
Output: [1, 84, 8400] float32 (84 = 4 box + 80 classes)
        Format: [x_center, y_center, width, height, class_scores...]
```

### BlazeFace (Face Detection)
```
Input:  [1, 128, 128, 3] float32 (0-1)
Output: 
  - boxes: [1, 896, 16] (16 = 4 box + 12 keypoints)
  - scores: [1, 896, 1]
```

### MobileFaceNet (Face Embedding)
```
Input:  [1, 112, 112, 3] float32 (-1 to 1)
Output: [1, 192] or [1, 512] float32 (L2 normalized)
```

### Hand Landmark (MediaPipe Hand)
```
Input:  [1, 256, 256, 3] float32 (0-1)
Output: 
  - landmarks: [1, 21, 3] (x, y, z normalized)
  - handedness: [1, 1] (0=left, 1=right)
  - flags: [1, 1] (detection confidence)
```

## Notes

- All models must be `.tflite` format
- Models should be optimized for mobile (quantized if possible)
- Keep model files under 50MB each for app size constraints
- Test inference speed on target devices before finalizing