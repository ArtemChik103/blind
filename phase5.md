**TASK: Phase 5 - Safety Guard & Hardware Control**

**1. Volume Button Control:**
Implement a listener for Volume Buttons (using `hardware_buttons` or `flutter_android_volume_keydown`).
*   **Scenario:** Blind users cannot easily find touch buttons.
*   **Logic:**
    *   **Volume Up:** Trigger "Info Mode" -> Speak current summary ("Вижу стул слева и человека прямо").
    *   **Volume Down:** Trigger "Silence Mode" -> Call `tts.stop()` immediately.
    *   **Implementation Detail:** Make sure to intercept the event so it doesn't actually change the phone system volume (if the plugin supports stream interception).

**2. UI Overlay (Accessibility):**
*   Create a minimal UI over the Camera Preview.
*   Add a large, invisible `GestureDetector` covering the whole screen.
    *   Double Tap: Switch between "Scan Mode" and "Text Reading Mode" (Stub for now).
*   Add `Semantics` to the whole screen describing the current status ("Камера активна, сканирую...").