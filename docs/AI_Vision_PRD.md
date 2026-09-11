# PRD — AI Vision

**Product Name:** AI Vision  
**Platform:** Android & iOS  
**Framework:** Flutter  
**Architecture:** On-Device AI / Offline-First  
**Version:** MVP v1.0

---

# 1. Product Overview

AI Vision adalah aplikasi mobile berbasis Flutter yang menggunakan Computer Vision dan Machine Learning secara lokal di perangkat untuk melakukan beberapa jenis deteksi melalui kamera secara real-time.

Aplikasi memiliki tiga mode utama:

1. Face Detection & Recognition
2. Object Detection
3. Hand / Finger Detection

Seluruh proses AI inference dilakukan secara lokal/on-device sehingga aplikasi dapat digunakan tanpa koneksi internet.

```text
Camera
   ↓
Camera Frame
   ↓
On-Device AI Model
   ↓
Detection / Recognition
   ↓
Result Overlay
```

Tidak ada kebutuhan untuk mengirim frame kamera ke server pada MVP.

---

# 2. Product Goals

## Primary Goals

- Menyediakan aplikasi Computer Vision real-time.
- Seluruh AI inference berjalan secara lokal.
- Bisa digunakan ketika offline.
- Kamera mampu mendeteksi objek secara real-time.
- Kamera mampu mendeteksi wajah.
- Kamera mampu mengenali wajah yang sudah terdaftar.
- Kamera mampu mendeteksi tangan dan jumlah jari.
- UI sederhana dan mudah digunakan.
- Modular sehingga mode AI baru dapat ditambahkan kemudian.

## Non-Goals MVP

MVP tidak mencakup:

- Cloud AI inference.
- Cloud database.
- Online user account.
- Cloud synchronization.
- Server-side image processing.
- Social features.
- Video recording.
- Automatic upload foto.

---

# 3. Target Users

## Primary

- Developer / AI experimentation
- Computer Vision demo
- Portfolio project
- Internal prototype
- Educational application

## Future

- Security / access control
- Attendance
- Smart inventory
- Retail
- Object identification
- Gesture-controlled application

---

# 4. Core Features

## 4.1 Home Dashboard

Home screen menjadi pusat navigasi seluruh detection mode.

```text
┌──────────────────────────────┐
│          AI VISION            │
│                              │
│  On-device AI • Offline      │
│                              │
│ ┌──────────────────────────┐ │
│ │ 👤 Face Recognition      │ │
│ │ Detect & recognize faces │ │
│ └──────────────────────────┘ │
│                              │
│ ┌──────────────────────────┐ │
│ │ 📦 Object Detection      │ │
│ │ Detect objects           │ │
│ └──────────────────────────┘ │
│                              │
│ ┌──────────────────────────┐ │
│ │ ✋ Hand Detection         │ │
│ │ Count fingers & gestures │ │
│ └──────────────────────────┘ │
│                              │
│             ⚙ Settings       │
└──────────────────────────────┘
```

---

# 5. Mode 1 — Face Detection & Recognition

Mode ini memiliki dua kemampuan berbeda:

### Face Detection

Mendeteksi apakah terdapat wajah pada frame.

### Face Recognition

Mencocokkan wajah dengan wajah yang sudah tersimpan secara lokal.

## 5.1 Detection Flow

```text
Camera
 ↓
Face Detector
 ↓
Face Found?
 ↓
Extract Face
 ↓
Generate Face Embedding
 ↓
Compare Local Database
 ↓
Match?
```

Jika tidak ditemukan:

```text
No face detected
```

Jika wajah ditemukan tetapi tidak dikenal:

```text
Unknown Person
```

Jika cocok:

```text
Budi Santoso
12 March 1998
Employee ID
EMP-001
```

---

# 6. Face Registration

User dapat mendaftarkan seseorang secara lokal.

Flow:

```text
Face Recognition
       ↓
Register New Person
       ↓
Input Person Data
       ↓
Capture Face
       ↓
Generate Face Embedding
       ↓
Save Local Database
```

Data:

```text
Full Name
Date of Birth
ID
Optional Notes
Face Embedding
Created At
```

Data personal dan embedding wajah disimpan lokal dan tidak dikirim ke server pada MVP.

---

# 7. Face Recognition Result

Ketika wajah cocok:

```text
┌──────────────────────────────┐
│                              │
│       ┌──────────────┐       │
│       │              │       │
│       │    FACE      │       │
│       │              │       │
│       └──────────────┘       │
│                              │
│     Budi Santoso             │
│     12 March 1998            │
│     EMP-001                  │
│                              │
│     Match: 94.8%             │
└──────────────────────────────┘
```

---

# 8. Mode 2 — Object Detection

Mode ini mendeteksi objek yang terlihat kamera.

Contoh:

```text
Cell Phone
Laptop
Bottle
Person
Chair
Cup
Keyboard
Mouse
Book
Backpack
```

Output:

```text
Object: Cell Phone
Confidence: 96%
```

---

# 9. Object Detection UI

```text
┌──────────────────────────────┐
│                              │
│    ┌──────────────────┐      │
│    │                  │      │
│    │     PHONE        │      │
│    │                  │      │
│    └──────────────────┘      │
│                              │
│    Cell Phone                │
│    96.4%                     │
│                              │
│──────────────────────────────│
│ Objects detected: 1          │
└──────────────────────────────┘
```

Jika beberapa objek:

```text
Objects detected: 4

Cell Phone     96%
Laptop         91%
Bottle         88%
Person         99%
```

---

# 10. Mode 3 — Hand / Finger Detection

Mode ini menggunakan hand landmark detection.

Model mendeteksi titik-titik penting pada tangan, kemudian aplikasi menentukan jari yang sedang terbuka.

Contoh:

```text
☝️ → 1
✌️ → 2
🤟 → 3
🖐️ → 5
✊ → 0
```

Output:

```text
2 Fingers
```

atau:

```text
Detected Fingers

Thumb    CLOSED
Index    OPEN
Middle   OPEN
Ring     CLOSED
Pinky    CLOSED

Total: 2
```

---

# 11. Finger Detection Algorithm

Pipeline:

```text
Camera
 ↓
Hand Detection
 ↓
Hand Landmarks
 ↓
Calculate Finger States
 ↓
Count Open Fingers
 ↓
Display Result
```

---

# 12. Gesture Detection

Setelah finger detection stabil, sistem dapat dikembangkan menjadi gesture detection.

MVP optional:

| Gesture | Output |
|---|---|
| ✊ | 0 |
| ☝️ | 1 |
| ✌️ | 2 |
| 🤟 | 3 |
| 🖐️ | 5 |
| 👍 | Thumbs Up |
| 👎 | Thumbs Down |

Gesture recognition tidak harus masuk MVP pertama, tetapi architecture harus memungkinkan penambahan fitur ini.

---

# 13. Camera Requirements

Camera harus mendukung:

- Real-time preview.
- Front camera.
- Rear camera.
- Camera switching.
- Permission handling.
- Frame processing.
- FPS monitoring.
- Detection overlay.
- Bounding boxes.
- Landmark rendering.

Target:

- Minimal usable inference: 15 FPS.
- Ideal inference: 20–30 FPS.

Inference tidak harus memproses setiap camera frame.

Contoh:

```text
Camera = 30 FPS

AI inference:
Frame 1
Frame 3
Frame 5
Frame 7
...
```

Hal ini membantu menjaga performa dan battery.

---

# 14. Offline Architecture

Seluruh AI pipeline berjalan di device.

```text
                    DEVICE
┌─────────────────────────────────────┐
│                                     │
│              Flutter                │
│                                     │
│ ┌──────────────┐                    │
│ │ Camera       │                    │
│ └──────┬───────┘                    │
│        ↓                            │
│ ┌──────────────────────────────┐    │
│ │ Frame Processing             │    │
│ └──────────────┬───────────────┘    │
│                ↓                    │
│ ┌──────────────────────────────┐    │
│ │ On-Device ML                 │    │
│ │                              │    │
│ │ Face Model                   │    │
│ │ Object Model                 │    │
│ │ Hand Model                   │    │
│ └──────────────┬───────────────┘    │
│                ↓                    │
│ ┌──────────────────────────────┐    │
│ │ Detection Engine             │    │
│ └──────────────┬───────────────┘    │
│                ↓                    │
│ ┌──────────────────────────────┐    │
│ │ Local Database               │    │
│ └──────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘

             NO CLOUD REQUIRED
```

---

# 15. Recommended Tech Stack

## Mobile

- Flutter
- Dart

## Architecture

- Clean Architecture
- Feature-based Architecture
- Repository Pattern
- Dependency Injection

## Camera

- Flutter `camera` package
- Camera frame/image stream
- Camera lifecycle handling

## Machine Learning Runtime

Primary recommendation:

- TensorFlow Lite / LiteRT-compatible runtime
- Model format: `.tflite`

Benefits:

- On-device
- Offline
- Mobile friendly
- Android support
- iOS support
- Custom model support
- Suitable for real-time inference

---

# 16. Object Detection Model

Untuk MVP:

- YOLO-family model
- Pretrained model untuk initial demo
- Export model ke TensorFlow Lite

Pipeline:

```text
YOLO
 ↓
Export
 ↓
TensorFlow Lite
 ↓
Flutter
```

Model awal dapat menggunakan dataset seperti COCO.

Contoh classes:

```text
person
bicycle
car
bottle
chair
laptop
cell phone
keyboard
mouse
book
etc.
```

Untuk object detection custom di masa depan, model dapat di-fine-tune dengan dataset sendiri.

---

# 17. Face Detection

Gunakan lightweight face detection model yang dapat berjalan on-device.

Pipeline:

```text
Camera
 ↓
Face Detection
 ↓
Face Bounding Box
 ↓
Face Crop
```

Face detection menjawab:

> "Ada wajah di mana?"

Face recognition menjawab:

> "Wajah ini milik siapa?"

---

# 18. Face Recognition

Pipeline:

```text
Face
 ↓
Face Alignment
 ↓
Face Embedding Model
 ↓
Embedding Vector
 ↓
Compare
 ↓
Local Database
```

Contoh embedding:

```text
Face A
Embedding:
[0.12, -0.32, 0.81, ...]
```

Database:

```text
Person
├── ID
├── Name
├── DOB
├── Face Embedding
└── Metadata
```

Comparison menggunakan similarity metric seperti cosine similarity.

---

# 19. Local Database

Recommended:

- SQLite
- Drift sebagai database abstraction

Database utama:

```text
persons
face_embeddings
settings
```

## persons

```text
id
full_name
date_of_birth
employee_id
notes
created_at
updated_at
```

## face_embeddings

```text
id
person_id
embedding
created_at
```

Relation:

```text
Person
   │
   └── Face Embedding(s)
```

---

# 20. Local Storage

Untuk configuration sederhana:

- SharedPreferences

Contoh:

```text
selected_mode
camera_facing
confidence_threshold
theme
```

Untuk structured data:

- SQLite / Drift

---

# 21. Application Architecture

Recommended structure:

```text
lib/
│
├── core/
│   ├── camera/
│   ├── ml/
│   ├── database/
│   ├── permissions/
│   ├── utils/
│   └── constants/
│
├── features/
│
│   ├── home/
│   │
│   ├── face_detection/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── object_detection/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── hand_detection/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── person_management/
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── extensions/
│
└── main.dart
```

---

# 22. ML Abstraction

UI tidak boleh langsung terikat dengan model ML tertentu.

Buat abstraction seperti:

```text
DetectionEngine
      │
      ├── FaceDetectionEngine
      ├── ObjectDetectionEngine
      └── HandDetectionEngine
```

Tujuannya agar model atau runtime dapat diganti tanpa membongkar UI dan business logic.

Contoh:

```text
Flutter UI
    ↓
Use Case
    ↓
Detection Repository
    ↓
Detection Engine
    ↓
ML Model
```

---

# 23. State Management

Recommended:

**Riverpod**

Alasan:

- Lightweight
- Type-safe
- Dependency injection
- Mudah untuk testing
- Cocok untuk modular architecture

State utama:

```text
CameraState
DetectionState
FaceRecognitionState
ObjectDetectionState
HandDetectionState
```

---

# 24. Navigation

Recommended:

**GoRouter**

Routes:

```text
/
├── /face
├── /objects
├── /hands
├── /persons
├── /persons/create
├── /persons/:id
└── /settings
```

---

# 25. Permissions

Required:

- Camera permission

Optional future:

- Photo Library
- Storage

MVP tidak membutuhkan:

- Location
- Microphone
- Contacts
- Internet
- Cloud account

Aplikasi tetap harus dapat menjalankan fitur utama ketika internet dimatikan.

---

# 26. Privacy & Security

Karena aplikasi memproses wajah dan data personal, privacy merupakan requirement utama.

Prinsip:

- Foto wajah tidak di-upload.
- Face embedding tidak dikirim ke server.
- Tidak menggunakan cloud recognition.
- Data disimpan lokal.
- User dapat menghapus data seseorang.
- User dapat menghapus seluruh database.
- Camera frame tidak disimpan secara permanen kecuali user secara eksplisit melakukan capture pada fitur masa depan.

Settings harus menyediakan informasi:

```text
Privacy

✓ AI processing happens on this device
✓ No camera images are uploaded
✓ Face data is stored locally
✓ Internet connection is not required
```

Untuk production, data biometrik lokal sebaiknya dilindungi menggunakan secure storage/encryption sesuai kebutuhan platform.

---

# 27. Performance Requirements

## Android

Target minimum:

```text
Android 8+
4 GB RAM recommended
```

## iOS

Target:

```text
iOS 15+
```

## Performance Target

```text
Camera Preview       ≥ 24 FPS
AI Inference         ≥ 15 FPS
UI                   ≥ 55 FPS
```

Pada device low-end, inference FPS boleh turun selama UI tetap responsive.

Model harus menggunakan quantization atau optimisasi lain jika diperlukan untuk menjaga latency dan memory usage.

---

# 28. Detection Confidence

## Object Detection

Initial threshold:

```text
confidence >= 0.50
```

Threshold harus configurable.

## Face Recognition

Recognition threshold juga harus configurable.

Contoh:

```text
Recognition Threshold
0.70
```

Jika similarity berada di bawah threshold:

```text
Unknown Person
```

Jangan menampilkan identitas jika confidence/similarity belum memenuhi threshold.

---

# 29. Error Handling

## Camera unavailable

```text
Camera unavailable.
Please check camera permission.
```

## Model unavailable

```text
AI model could not be loaded.
```

## No face

```text
No face detected.
```

## Unknown face

```text
Unknown person.
```

## No object

```text
No object detected.
```

## No hand

```text
No hand detected.
```

Error harus ditampilkan sebagai user-friendly message tanpa mengekspos stack trace.

---

# 30. Settings

Settings MVP:

```text
Settings

Detection
├── Object Confidence
├── Face Recognition Threshold
└── Inference FPS

Camera
├── Default Camera
└── Mirror Front Camera

Appearance
├── Dark Mode
└── Light Mode

Data
├── Registered Persons
├── Clear Face Database
└── Reset App
```

---

# 31. MVP Scope

## Must Have

### Camera

- Camera preview
- Camera switching
- Permission handling
- Frame processing

### Object

- Object detection
- Bounding box
- Object name
- Confidence

### Hand

- Hand detection
- Finger counting
- Landmark visualization

### Face

- Face detection
- Face bounding box
- Person registration
- Face embedding
- Local recognition
- Person information

### Storage

- SQLite
- Local face data

### Architecture

- Feature-based architecture
- ML abstraction
- Repository pattern
- Riverpod
- GoRouter

---

# 32. Future Features

## Gesture Control

```text
✋ → Open menu
✌️ → Next
👍 → Confirm
👎 → Cancel
```

## Custom Object Detection

User dapat menggunakan custom model:

```text
Custom Dataset
     ↓
Train
     ↓
Export TFLite
     ↓
Import Model
     ↓
AI Vision
```

## OCR

Future camera capabilities:

```text
Invoice
KTP
Barcode
Text
Serial Number
```

## Pose Detection

```text
Body
 ↓
Pose Landmark
 ↓
Movement Detection
```

---

# 33. Development Roadmap

## Sprint 1 — Foundation

```text
Flutter project
Architecture
Routing
Theme
Camera abstraction
Permission
Home UI
```

## Sprint 2 — Object Detection

```text
TFLite runtime
YOLO model
Camera frame processing
Bounding box
Confidence
Performance optimization
```

## Sprint 3 — Hand Detection

```text
Hand model
Landmarks
Finger state detection
Finger counting
Gesture foundation
```

## Sprint 4 — Face Detection

```text
Face detector
Bounding box
Face crop
Camera optimization
```

## Sprint 5 — Face Recognition

```text
Embedding model
SQLite
Person registration
Embedding storage
Similarity comparison
Recognition UI
```

## Sprint 6 — Polish

```text
Performance
Memory optimization
Battery optimization
Error handling
Animations
Dark mode
Testing
```

## Sprint 7 — Release

```text
Android testing
iOS testing
Release build
Privacy documentation
Store assets
Production release
```

---

# 34. Definition of Done

## Object Detection

User mengarahkan kamera ke HP.

Expected:

```text
┌──────────────────────────────┐
│                              │
│       ┌──────────────┐       │
│       │    PHONE     │       │
│       └──────────────┘       │
│                              │
│       Cell Phone             │
│       96.4%                  │
└──────────────────────────────┘
```

Bounding box muncul secara real-time.

## Hand Detection

User menunjukkan dua jari:

```text
✌️
```

Expected:

```text
2 Fingers
```

## Face Recognition

User mendaftarkan:

```text
Budi Santoso
12 March 1998
EMP-001
```

Kemudian kamera diarahkan ke wajah Budi.

Expected:

```text
Budi Santoso
12 March 1998
EMP-001
Match: 94.8%
```

## Offline

Setelah aplikasi terinstall:

```text
Wi-Fi OFF
Mobile Data OFF
```

Semua detection utama tetap berjalan.

---

# 35. Final Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Architecture | Clean Architecture |
| Structure | Feature-based |
| State Management | Riverpod |
| Navigation | GoRouter |
| Camera | Flutter Camera |
| ML Runtime | TensorFlow Lite / LiteRT-compatible runtime |
| Object Detection | YOLO-family model |
| Face Detection | On-device face detection model |
| Face Recognition | Face Embedding Model |
| Hand Detection | Hand Landmark Model |
| Database | SQLite |
| DB Abstraction | Drift |
| Local Preferences | SharedPreferences |
| Dependency Injection | Riverpod |
| Networking | None for MVP |
| Cloud | None |
| Backend | None |
| Authentication | None |
| Analytics | None |
| Crash Reporting | None for offline MVP |

---

# 36. Mandatory Engineering Principles

AI coding agent wajib mengikuti prinsip berikut:

### 1. Offline First

> The application must be designed as an offline-first, on-device AI application. No camera frame, face image, face embedding, or detection data may be sent to a remote server in MVP. All AI inference must happen locally on the device.

### 2. Model Independence

> Do not tightly couple the Flutter UI with any specific ML model or ML runtime. Create an abstraction layer so models can be replaced independently from presentation and business logic.

### 3. Performance First

> Camera preview, UI rendering, and ML inference must be treated as separate workloads. Avoid blocking the Flutter UI thread with heavy image processing or model inference.

### 4. Modular Features

> Face Detection, Object Detection, Hand Detection, and Person Management must be independently structured features.

### 5. No Premature Cloud Dependency

> Do not introduce Firebase, REST APIs, cloud storage, cloud inference, authentication servers, or other remote services unless explicitly required in a future phase.

### 6. Secure Biometric Data

> Face embeddings and personal information must remain local in MVP and must not be logged, exposed in debug output, or transmitted externally.

### 7. Replaceable ML Models

> ML models must be loaded through dedicated model services/providers. Replacing a `.tflite` model must not require changes to presentation-layer code.

---

# 37. Recommended Build Order

Development should follow this order:

```text
1. Flutter Foundation
        ↓
2. Camera Engine
        ↓
3. Frame Processing
        ↓
4. Object Detection
        ↓
5. Hand Detection
        ↓
6. Face Detection
        ↓
7. Face Embedding
        ↓
8. Face Recognition
        ↓
9. Local Database
        ↓
10. Performance Optimization
        ↓
11. Testing
        ↓
12. Production Release
```

Object Detection should be the first AI milestone because it validates the complete pipeline:

```text
Camera Stream
      ↓
Frame Processing
      ↓
Preprocessing
      ↓
ML Inference
      ↓
Postprocessing
      ↓
Detection Result
      ↓
UI Overlay
```

Once this pipeline is stable, additional detection engines can reuse the same camera and ML infrastructure.
