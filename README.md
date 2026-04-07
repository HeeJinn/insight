# Offline Multi-Platform Biometric Attendance Framework

A Flutter thesis prototype that replaces manual classroom roll calls with a fast, non-intrusive, offline facial recognition attendance system. The app includes an Admin Dashboard (registration + analytics + logs), Kiosk Mode (real-time scanning), and thesis-oriented Insights views for evaluation and reporting.

## Features

- **Multi-Platform Support**: Android, iOS, Windows, macOS, Web
- **Offline Operation**: All ML inference happens locally on device
- **Fast Recognition**: Target latency < 1 second per face scan
- **Admin Dashboard (Material 3 UX)**: Student registration, student management (search/filter/edit/delete), attendance log viewing
- **Kiosk Mode**: Real-time camera scanning for attendance
- **Insights Module**: Search by student name/ID, daily coverage metrics, recent check-ins, full logs view
- **First-Run Experience**: Tutorial tabs + privacy policy consent flow

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: flutter_riverpod
- **Navigation**: go_router
- **ML Engine**: tflite_flutter (Face Detection + Face Recognition)
- **Storage**: hive_ce (offline NoSQL)
- **Image Processing**: image (Dart native cropping)
- **Camera**: camera package
- **Image Picking**: image_picker, file_picker

## Setup

1. Clone the repository
2. Run `flutter pub get`
3. Download TFLite models and place in `assets/models/`:
   - Face Detection Model: Download BlazeFace or UltraFace TFLite model (e.g., from https://github.com/hollance/BlazeFace-PyTorch or similar)
   - Face Recognition Model: Download MobileFaceNet TFLite model (e.g., from https://github.com/sirius-ai/MobileFaceNet_TF or similar)
   - Rename to `face_detection.tflite` and `face_recognition.tflite`
4. Run `flutter pub run build_runner build` (for Hive adapters)
5. Run the app: `flutter run`

## Model Details

- **Face Detection**: Input 320x240x3, Output bounding box [x,y,w,h] normalized
- **Face Recognition**: Input 112x112x3, Output 128D embedding

Ensure models match these input/output shapes.

## Architecture

### Registration Flow

1. Admin inputs student details (Name, ID)
2. Captures/uploads 5 baseline photos
3. Processes photos through TFLite Detection (crop) and Recognition (embeddings)
4. Saves baseline embeddings to Hive database

### Attendance Flow

1. Live camera feed in Kiosk Mode
2. TFLite Detection identifies face bounding box
3. Image package crops face from frame
4. TFLite Recognition generates live embedding
5. Calculates distance to stored embeddings
6. Logs attendance if below threshold

## Performance Optimizations

- Heavy image processing in Dart Isolates
- Optimized camera processing loop
- Lightning-fast Hive storage
- Cross-platform TFLite inference

## Constraints

- Strictly offline, no external APIs
- Multi-platform compatible (no Google ML Kit)
- Uses isolates for UI thread protection

## Thesis-Oriented System Insights

The prototype now exposes measurable indicators that can be cited in a thesis paper and presentation:

- **Adoption / Enrollment Depth**: total registered students and completion of baseline samples.
- **Operational Throughput**: total attendance logs and daily logs.
- **Daily Coverage**: percentage of unique students recognized in a day.
- **Traceability**: searchable logs by student name or ID for audit-ready verification.
- **Privacy Posture**: explicit first-run consent and local-only storage workflow.

These indicators are visible in-app (Admin/Insights) and can be mapped to evaluation criteria such as usability, responsiveness, reliability, and deployment feasibility.

## UI/UX Notes (Material 3)

- Uses Material 3 components (AppBar, TabBar/TabBarView, SearchBar, Cards, FilterChip, Filled/Outlined buttons).
- Responsive behavior is designed for portrait and landscape using bounded layouts and scroll-safe content containers.
- Admin flows are organized into clear tabs: Register, Students, Logs.
