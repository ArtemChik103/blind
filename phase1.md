**TASK: Phase 1 - Project Skeleton & Safety Layer**

**1. Dependencies & Configuration:**
Update `pubspec.yaml` with these exact packages (use compatible versions):
*   `flutter_riverpod`, `riverpod_annotation`, `dev:riverpod_generator`, `dev:build_runner`
*   `camera`, `permission_handler`
*   `shared_preferences`
*   `google_mlkit_object_detection`, `google_mlkit_commons`
*   `flutter_tts`
*   `vibration`
*   `wakelock_plus` (to keep screen on)

**2. Folder Structure:**
Create this strict structure:
*   `lib/core/constants/` (App strings, config)
*   `lib/core/services/` (SharedPrefs, Permissions)
*   `lib/features/safety/presentation/` (Warning Screen)
*   `lib/features/vision/` (Camera & ML logic)
*   `lib/main.dart`

**3. Feature: Warning Screen (Mandatory):**
Implement `WarningScreen` widget using ConsumerWidget.
*   **UI:** High contrast (Black background, White text).
*   **Text (Russian):** "ВНИМАНИЕ! Это приложение — прототип. Оно может ошибаться. НЕ ИСПОЛЬЗУЙТЕ его как единственное средство навигации. Всегда используйте белую трость. Вы принимаете риск на себя."
*   **Controls:**
    *   Checkbox: "Я понимаю и принимаю условия".
    *   Button: "Запустить Сонар" (Disabled until checkbox is true).
*   **Logic:** On button press, save boolean `has_accepted_risks` to `SharedPreferences` and navigate to `/camera`.

**4. App Initialization (`main.dart`):**
*   Initialize `WidgetsFlutterBinding`.
*   Initialize `SharedPreferences` (create a Provider for it).
*   Check `has_accepted_risks`. If true -> go to CameraRoute. If false -> WarningRoute.
*   Wrap app in `ProviderScope`.