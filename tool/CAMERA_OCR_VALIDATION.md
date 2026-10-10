# Camera OCR validation

This probe exercises the application's `requestWebCameraAccess()`, mounted
`WebCameraPreview`, PNG camera capture, browser OCR bridge, real Tesseract
recognition, and Dart `MedicationOcrDetector`. Chromium receives a synthetic
`canvas.captureStream()` camera carrying each fixture. This validates the
browser camera-to-recognition path; it does not measure physical camera optics,
autofocus, motion, permissions on a user's device, or native OCR adapters.

Prepare six distinct official-source labels with documented low-light, blur,
tilt, glare, and cylindrical projection. This needs Python with Pillow and NumPy,
plus `curl`. The script records source URLs, input hashes, and transformation
parameters in its generated manifest. The source inventory is also saved in
`tool/camera_ocr_fixture_sources.json`.

```sh
python3 -m venv /private/tmp/mediary-camera-fixture-env
/private/tmp/mediary-camera-fixture-env/bin/pip install pillow numpy
/private/tmp/mediary-camera-fixture-env/bin/python tool/prepare_camera_ocr_fixtures.py \
  --output-dir /private/tmp/mediary-cylinder-fixtures
```

Optional `--benadryl-camera-screenshot` and `--excedrin-review-screenshot`
arguments reproduce the two supplied private screenshots using their documented
crop rectangles. Those inputs and generated capture artifacts must stay local.
The six official-source cases do not need private screenshots.

Install Playwright in a temporary directory, or use an existing installation:

```sh
mkdir -p /private/tmp/mediary-camera-validation
npm install --prefix /private/tmp/mediary-camera-validation playwright
flutter build web --target tool/camera_ocr_probe.dart --output /private/tmp/mediary-camera-probe-build
node tool/test_camera_ocr.mjs \
  --manifest /private/tmp/mediary-cylinder-fixtures/manifest.json \
  --output /private/tmp/mediary-camera-validation/results \
  --build-dir /private/tmp/mediary-camera-probe-build \
  --playwright /private/tmp/mediary-camera-validation/node_modules/playwright/index.mjs \
  --controls
```

The runner defaults to the installed macOS Chrome path; pass `--chrome` on
other systems. The manifest contains at least five distinct image fixtures:

```json
{
  "fixtures": [
    {
      "id": "excedrin-cylinder-dim",
      "path": "excedrin-cylinder-dim.png",
      "expectedMedicationName": "Excedrin Migraine",
      "condition": "cylindrical label, low light, perspective skew",
      "sourceUrl": "https://example.com/original-photo"
    }
  ]
}
```

Fixture paths may be absolute or relative to the manifest. An array of accepted
names is allowed for `expectedMedicationName`. Record how each image was sourced
and degraded in the manifest; generated degradations must be distinguished from
real low-condition photos. Use multiple medications rather than five variants
of one product. Include a too-small or unreadable image to verify manual review.

Each run writes `results.json`, full-resolution captured PNGs, and camera preview
screenshots. Results include input hashes, frame dimensions, requested camera
constraints, unmodified OCR text, detected medication, confidence, errors, and
elapsed time. Each engine pass also records the real raw text, line confidence,
and segmentation mode. Every normal fixture must reach the real engine; worker
unavailability fails validation instead of being counted as manual review.
Evidence-capable bridges also record the returned text and
`recoveredUncertainText` flag. The runner verifies that the Dart detector preserves
the raw evidence text and caps identification confidence at 0.65 when uncertain
text was recovered.
Confidence is the detector's identification score, not a calibrated
probability of correctness. Full PNG signatures and unchanged frame dimensions
are asserted. Failure to identify is reported as manual review; an unexpected
nonempty name is reported separately. Add `--require-all-identified` only when
all fixtures are intended to be readable.

A 32 × 32 sampled RGB comparison also verifies that the captured video contains
the current fixture, allowing a small difference for browser video color
conversion. This catches stale frames even when consecutive fixtures have the
same dimensions. `acceptedMedicationNames` can list safe, explicitly accepted
brand/formulation or generic names while keeping one preferred expected name.
An intentionally unreadable image can use `expectedManualReview: true` and no
expected name. Its result must remain unnamed with a manual-review error. An
unexpected nonempty name or harness failure gives the runner a failing exit
status; readable-image misses remain visible in the results summary.

`--controls` tests unavailable camera access, an empty stream, an unavailable
fixture, and a single induced OCR initialization failure followed by a real
engine recovery scan. These controls inject failure conditions; they never
substitute medication text or recognition results.

For a browser-preprocessing baseline, pass `--bridge-html old-web-index.html`.
The runner loads the inline `MediaryOcr` bridge from that HTML before scanning.
It explicitly wraps the old plain-string method as evidence with
`recoveredUncertainText: false`, preventing new recovery logic from leaking into
the baseline. It keeps the compiled Dart parser constant, so this comparison attributes only
changes in the browser OCR bridge. To compare an older Dart parser too, build
the probe target in that older checkout and pass its `--build-dir` separately.
