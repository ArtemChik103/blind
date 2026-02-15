**TASK: Phase 2 - Optimized Vision Service**

**1. Camera Controller Provider:**
Create a `CameraService` class and a corresponding Riverpod provider.
*   Logic: Initialize the first back-facing camera.
*   **Config:** Use `ResolutionPreset.medium` (VGA 640x480). Do NOT use High/Max resolution (it kills ML performance).
*   Audio: `enableAudio: false`.
*   **Wakelock:** Enable `WakelockPlus.enable()` when camera starts.

**2. Advanced Image Stream with Throttling:**
Implement `startImageStream` inside the service.
*   **Constraint:** Camera yields 30 FPS. We only need 2-3 FPS for analysis.
*   **Implementation:**
    ```dart
    DateTime? _lastRun;
    void onImageStream(CameraImage image) {
      if (_lastRun != null && DateTime.now().difference(_lastRun!) < Duration(milliseconds: 500)) {
        image.close(); // IMPORTANT: Close unused frames immediately to prevent memory leaks on Android
        return;
      }
      _lastRun = DateTime.now();
      // Pass image to processing logic (implemented in next phase)
    }
    ```

**3. Auto-Torch (Flashlight) with Pixel Striding:**
Implement a `LightMonitor` logic.
*   **Goal:** Turn on flash if the room is dark.
*   **Performance Hack (Pixel Striding):**
    *   Do NOT loop through all pixels. The image buffer is huge.
    *   Read the Y-plane (luminance) buffer.
    *   Loop with a step: `for (int i = 0; i < bytes.length; i += 50)`.
    *   Calculate average brightness.
*   **Logic:**
    *   If average < 30 (Dark) -> `controller.setFlashMode(FlashMode.torch)`.
    *   If average > 100 (Bright) -> `controller.setFlashMode(FlashMode.off)`.
    *   Add a simple "hysteresis" (debounce) to prevent flickering (don't switch modes more than once every 2 seconds).