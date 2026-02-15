**TASK: Phase 3 - Isolate-based ML Inference**

**1. InputImage Converter:**
Create a static helper `ImageUtils.convertCameraImageToInputImage(CameraImage image)`.
*   Handle YUV420 format correctly.
*   Handle Rotation (get sensor orientation).

**2. The Compute Function (The Brain):**
Create a Top-Level function (outside any class) named `runObjectDetection`.
*   **Input:** A Map or Record containing: `bytes`, `height`, `width`, `rotation`, `format`.
*   **Action:**
    1. Reconstruct `InputImage` inside the Isolate.
    2. Initialize `ObjectDetector` (EfficientDet-Lite0 recommended).
    3. Run `processImage`.
    4. Map results to a custom DTO `List<SimpleObject>` (String label, Rect box) to pass back to UI thread.
    5. Dispose detector.
*   **Return:** The list of objects.

**3. Integration:**
Connect this to the `CameraService` stream from Phase 2.
*   Use `compute(runObjectDetection, data)` inside the stream callback.
*   Update a `StateProvider<List<SimpleObject>>` with the results.
*   **Error Handling:** Ensure the app doesn't crash if ML Kit fails on a frame. Wrap in try-catch.