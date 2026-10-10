# Medication camera recognition: difficult-label investigation

Validated on 2026-10-10 using Chromium, Tesseract.js 4.1.1, and the application's
actual browser camera capture and Dart medication detector.

## Findings

Curved packaging compresses side lettering and changes the baseline across a
word. The existing image passes rotate flat crops by ±6 degrees; they do not
reconstruct text hidden around the cylinder. Skew also makes line segmentation
less reliable, as described in [Tesseract's quality guidance](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html).

The Excedrin test exposed two additional, directly reproducible failures:

1. The engine returned `EXCEDRIN` and `EXCEDRIN)` in separate attempts, with line
   scores of 20.95 and 38.34. The bridge discarded both because its cutoff was
   45. The parser never received the correctly read brand.
2. Excedrin and caffeine were absent from the parser's aliases. The readable
   formulation was also rendered as `MGRAINE RELIEF`, which exact matching
   rejected. A crisp Excedrin label could therefore fail independently of blur.

## Implemented correction

The bridge preserves a standalone word only when it repeats in at least two
recognition attempts and meets a minimum readability score. It does not recover
single uncertain reads or multiword noise. Recovered text carries an explicit
uncertainty flag through the web adapter, and the detector caps its identification
score at 0.65. The score is a ranking heuristic, not a calibrated probability.

The parser recognizes Excedrin's Migraine, Extra Strength, and Tension Headache
formulations, retains caffeine in ingredient combinations, and allows a single
OCR edit of `MIGRAINE` only after separately recognizing Excedrin. Ambiguous or
conflicting formulations still require manual review. Catalog selection rejects
unknown extra ingredients, incomplete formulas concealed by a brand synonym,
and incompatible ingredient-specific strengths, including repeated strengths.

The supported formulas were checked against the primary labels for
[Excedrin Migraine](https://www.dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=c4168e4d-3dfc-4e51-a32e-14704cb59c66)
and [Excedrin Tension Headache](https://www.dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=12c074d1-81ac-47d2-8747-b018cda0058a).

Geometric retry experiments did not improve identity recognition on this set
and added noisy output. They were excluded from the final change. The measured
Excedrin improvement comes from preserving repeat readings and correcting the
missing formulation support; it does not establish general cylinder unwrapping.

## Image test results

Six distinct official manufacturer/DailyMed images were degraded reproducibly
with dim light, blur, tilt, glare, or cylindrical projection. All six used
1024 × 768 synthetic camera frames. An actual cylindrical bottle packshot was
used for Excedrin; Advil, Aleve, and Claritin used simulated cylinder projection.
No medication text or OCR result was injected into these tests.

| Input | Difficult condition | Baseline identity | Final identity | Final score |
| --- | --- | --- | --- | --- |
| Excedrin Migraine bottle | Curved bottle, dim exposure, 11° tilt, blur | Manual review | Excedrin Migraine | 0.65 |
| Advil | Cylinder projection, dim side lighting, 8° tilt | Ibuprofen | Ibuprofen | 0.70 |
| Tylenol Extra Strength | Dim exposure, 13° tilt, defocus blur | Acetaminophen | Acetaminophen | 0.94 |
| Aleve | Cylinder projection, dim side lighting, 14° tilt, blur | Aleve | Aleve | 0.94 |
| Claritin | Cylinder projection, glare, dim exposure, 7° tilt, blur | Claritin | Claritin | 0.70 |
| Benadryl | Dim exposure, 10° tilt, blur | Benadryl | Benadryl | 0.65 |

The prior user Benadryl camera-preview screenshot also returned Benadryl. The
new Excedrin screenshot provides only an 83 × 82 review thumbnail; that input
correctly stayed in manual review. It cannot validate the original full-resolution
bottle capture. Private input photographs and captures remain outside the repository.

The eight-case final run had seven accepted identities, one intended manual
review, no unexpected medication names, and no harness failures. The browser
baseline comparison holds the updated Dart parser constant and changes only the
OCR bridge; parser changes are covered by separate regression tests.

## Verification and limits

The probe exercises the mounted `WebCameraPreview`, incoming video stream,
`captureWebCameraFrame()`, PNG conversion, real Tesseract, and
`MedicationOcrDetector`. It asserts PNG signatures, unchanged frame dimensions,
and current-frame pixel correspondence. Sampled mean RGB error was below 10/255
for every frame, allowing browser video color conversion while detecting stale
frames. Real engine attempts and raw text were recorded separately from filtered
text, and the recovered-text score cap was checked.

Four controls passed: denied camera access, an empty stream, a missing fixture,
and worker initialization failure followed by a successful real-engine retry.

Final repository checks passed: `flutter analyze`, all 435 VM Flutter tests,
all five browser adapter tests, all nine browser bridge tests, and
`flutter build web`. The camera probe is a test-only build target; the production
build continues to use `lib/main.dart`.

These tests use `canvas.captureStream()` as a synthetic camera. They do not
measure hardware autofocus, motion, changing room light, or native Vision/ML Kit
recognition. Correct brand/ingredient identity does not verify an exact RxNorm
product, strength, form, or schedule. Severe curvature and obscured lettering
still need another camera angle or manual search.

See [the recorded public results](camera-ocr-results.json),
[source inventory](../tool/camera_ocr_fixture_sources.json), and
[reproduction instructions](../tool/CAMERA_OCR_VALIDATION.md).
