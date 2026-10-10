# Camera photo confirmation

The shutter captures a frame and pauses the browser video immediately. The app
stops the live camera and opens **Review photo**, showing the captured image with
**Use photo** and **Retake**. Retake or Back discards the image without OCR or
a scan write. Use photo starts recognition once, retains the frozen image while
processing, and opens Review Medication when recognition finishes.

Native iOS/Android camera capture continues to use the system image picker. Its
returned photo goes through the same in-app confirmation screen. The operating
system may also show its own camera confirmation. Gallery selection keeps its
existing direct recognition flow.

## Mobile and resource handling

- The entire photo remains visible with its original aspect ratio. Preview
  decoding fits within 1600 × 1600 pixels; recognition receives the original
  bytes. The decoded preview is evicted when the review closes.
- Normal portrait phone layouts show both actions without scrolling. Short
  landscape screens and enlarged text use a scrollable layout, with actions
  stacking vertically when needed and retaining minimum 44-point touch targets.
- Camera tracks stop during review, when the preview is inactive, and when the
  browser goes into the background. Retake and foreground resume start a fresh
  stream. The shutter waits for a connected live frame instead of capturing a
  loading frame, and a late permission result releases its tracks.
- Concurrent camera requests share one pending request. Capture and approval
  guards prevent repeated taps from creating duplicate photos or OCR jobs.
- Recognition runs before metadata saving. The result screen saves one complete
  scan using its existing retry flow, so a slow server acknowledgment does not
  block local recognition or the result screen.

## Verification

The photo review regression cases cover no recognition/saving before consent,
retake and Back, unchanged image bytes, duplicate approval, canceled and late
capture, invalid image data, retry after approval failure, and a slow scan save.
The layout matrix covers iOS and Android at 320 × 640, 402 × 874, and 568 × 320,
with 1× and 3× text. Browser tests exercise actual video/canvas capture with a
synthetic camera, freeze, stream shutdown, retake, background/foreground resume,
and delayed permission completion.

Passed checks:

```sh
flutter analyze
flutter test
sh tool/test_browser_camera.sh
flutter build web
flutter build ios --simulator --debug --no-codesign
flutter build apk --debug
```

The VM suite passes 456 tests, including 21 photo-review tests; both browser
camera tests pass. The iOS build uses the project's local ignored Firebase
configuration, which is not part of these commits. These checks verify app flow,
layout, browser camera lifecycle, and mobile compilation. Physical device optics
and manufacturer-specific native camera interfaces were not exercised.
