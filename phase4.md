**TASK: Phase 4 - Spatial Logic & TTS Engine (Russian)**

**1. Dictionary & Translation:**
Create a constant `Map<String, String> translationMap`.
*   Map standard COCO labels to Russian:
    *   'person': 'человек'
    *   'chair': 'стул'
    *   'table': 'стол'
    *   'door': 'дверь'
    *   'tv': 'монитор'
    *   'laptop': 'ноутбук'
    *   (Add 10-15 common household items).

**2. Spatial Logic Class:**
Create `SpatialCalculator`.
*   **Inputs:** Object BoundingBox, ScreenWidth.
*   **Zones:**
    *   `center.dx < width * 0.3` -> "Слева"
    *   `center.dx > width * 0.7` -> "Справа"
    *   Else -> "Прямо"
*   **Distance:**
    *   `boxArea / screenArea > 0.6` -> "Вплотную"
    *   `boxArea / screenArea > 0.2` -> "Рядом"
    *   Else -> "" (Ignore distant objects).

**3. Smart TTS Service:**
Implement `TtsService` provider.
*   Config: Language `ru-RU`, SpeechRate `0.5`.
*   **Method `speakUrgent(String text)`:**
    *   Call `stop()` to interrupt current speech.
    *   Call `speak(text)`.
*   **Filtering (Anti-Spam):**
    *   Maintain a `_lastSpokenLabel` and `_lastSpokenTime`.
    *   Logic: If `currentLabel == _lastSpokenLabel` AND `timeDiff < 4 seconds`, DO NOT speak.

**4. Wiring it up:**
In the Camera loop:
1. Get objects.
2. Translate label.
3. Calculate position ("Стул слева").
4. Send to TTS service.