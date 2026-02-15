# Sonar

Sonar is a Flutter-based assistive vision prototype for visually impaired users.
It captures camera frames, detects nearby objects, and announces concise spatial
alerts using Russian speech and haptic feedback.

## Safety Notice

This app is a prototype and can make mistakes.
Do not use it as the only navigation aid.
Always use your white cane and follow safe mobility practices.

## Core Features

- Real-time camera stream with throttled frame processing.
- On-device object detection using EfficientDet Lite0 on Android.
- Automatic fallback to ML Kit base detector if local model inference fails.
- Spatial interpretation of detections:
  - Direction: left, center, right.
  - Distance buckets: near, close.
- Voice output (`flutter_tts`, `ru-RU`) with anti-spam gating.
- Haptic cues (`vibration`) for informational and urgent alerts.
- Gesture controls on camera screen:
  - Double tap: toggle silent mode.
  - Long press: voice summary of current scene.
- Risk acceptance and accessibility mode persistence via `shared_preferences`.

## Tech Stack

- Flutter (Dart 3)
- State management: `flutter_riverpod` + code generation (`riverpod_annotation`)
- Camera: `camera`
- Vision:
  - `tflite_flutter` (EfficientDet Lite0 local model)
  - `google_mlkit_object_detection` fallback
- Accessibility output:
  - `flutter_tts`
  - `vibration`
- Utilities:
  - `permission_handler`
  - `shared_preferences`
  - `wakelock_plus`
  - `path_provider`

## Architecture Overview

Code is organized under `lib/` by feature and concern:

- `lib/core/`
  - Constants and shared services (TTS, haptics, preferences, accessibility modes).
- `lib/features/safety/`
  - Initial warning/consent flow.
- `lib/features/vision/domain/`
  - Entities and pure logic (`SimpleObject`, spatial calculation, post-processing).
- `lib/features/vision/services/`
  - Camera orchestration, detection pipelines, isolate workers, model loading.
- `lib/features/vision/presentation/`
  - Camera UI and accessibility interaction layer.

### Performance Design

- Camera uses `ResolutionPreset.medium` and frame throttling (~500 ms cadence).
- YUV conversions run off the UI thread via `compute(...)`.
- EfficientDet inference runs in a dedicated isolate (`tflite_isolate_worker.dart`).
- Flash control uses lightweight brightness sampling and hysteresis.

## Project Structure

```text
lib/
  core/
    constants/
    services/
  features/
    safety/presentation/
    vision/
      domain/
      presentation/
      services/
assets/
  models/
    efficientdet_lite0.tflite
    coco_labels_en.txt
test/
```

## Getting Started

### Prerequisites

- Flutter SDK installed and configured.
- Android Studio / Android SDK.
- Physical Android device recommended for camera + TFLite testing.

### Install Dependencies

```bash
flutter pub get
```

### Generate Riverpod Files

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run Tests

```bash
flutter test
```

### Run the App

```bash
flutter run
```

## Platform Permissions

### Android

This project requests camera access at runtime. Ensure camera permission exists
in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS

If running on iOS, ensure `ios/Runner/Info.plist` includes:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required to detect nearby objects.</string>
```

## Current Limitations

- Prototype-level reliability; detection confidence varies by scene/light.
- Voice interaction text is currently Russian-focused.
- Spatial distance is coarse (`near` / `close`) and based on bounding-box area.
- Some services (for example volume-key stream) are scaffolded for extension.

## Notes for Contributors

- Keep frame processing and heavy image work off the UI thread.
- Preserve accessibility semantics in all user-facing widgets.
- Keep feature logic testable in `domain` and `services`.
