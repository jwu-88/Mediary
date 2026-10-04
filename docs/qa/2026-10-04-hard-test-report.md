# Web and iOS hard-test audit and fix plan

Date: October 4, 2026. Application: Mediary. All confirmed issues below have been implemented and committed by feature on `codex/hard-test-fixes`. The branch includes the original scanner/catalog changes committed as `2c6f979`.

Three subagents used separate frozen copies and disposable data. Chrome tests used isolated profiles; native tests used a dedicated iPhone SE simulator running iOS 27. The primary checkout, other agents' simulator/browser sessions, production accounts, and production Firestore records were left unchanged.

## Findings and implemented fixes

| Priority | Reproduction / observed problem | Implemented fix | Feature commit |
|---|---|---|---|
| P1 | DST fall-back repeated a civil date; invalid dates/times/zones normalized silently; equivalent times and sanitized schedule IDs collided. Spring-forward metadata disagreed with the actual reminder time. | Iterate civil dates, validate inputs strictly, deduplicate slots, encode schedule identities, and retain the actual DST-adjusted time. | `3eab37f` |
| P1 | An outdated dose snapshot reset a remotely taken occurrence to `due`. | Reconcile through transactions that read current records and preserve terminal actions. | `073a23e` |
| P1 | Repository profile payloads included `photoUrl`, which the checked-in rules rejected. | Align validated profile fields with repository writes. | `50adde0` |
| P1 | Unrecorded blood type displayed as confirmed O+. | Preserve missing blood type as unknown; keep the picker responsive; describe empty health summaries accurately. | `50adde0`, `a671df0` |
| P1 | Camera capture always used the demo request; empty image data invented Amoxicillin at high confidence. | Capture native camera photos and browser video frames; allow demo recognition only for an explicit sample request; reject empty bytes. | `79d1dcc`, `a6f68db` |
| P1 | The real iOS plugin denied notifications while the app reported them available; scheduling raised native error 2003. A large regimen could replace nearer pending alerts. | Read authorization, skip unauthorized scheduling, and select the nearest 64 future iOS reminders in time order. | `45264c0` |
| P2 | Delayed callbacks notified a disposed store or crossed account sessions; sign-out retained subscriptions. | Guard callbacks and delayed mutations with a session generation, cancel subscriptions, and detach the account store on sign-out. | `8bd73f5`, `ca8450b` |
| P2 | A 25-dose day counted only the first 12 entries. | Supply all of today's doses to dashboard statistics. | `16bc278` |
| P2 | Reports disagreed about skipped/missed counts, counted missed days as doses, mislabeled rolling weekdays, and averaged cancelling/padded timing values. | Share explicit missed counts, exclude pending future doses from misses, use matching weekdays, and average absolute offsets per recorded taken dose. | `16bc278` |
| P2 | Rules accepted impossible dates, reversed ranges, malformed time-list values, invented timezones, and non-finite dosage values. | Validate calendar dates, time values, ranges, finite positive amounts, and supported IANA names in the persisted schema. | `50adde0` |
| P2 | Malformed HTTP 200 catalog responses appeared successful or fabricated a generic medication detail. | Reject malformed structures/identities, preserve valid no-match responses, and leave failures retryable. | `cd92912` |
| P2 | A narrow picker overflowed after keyboard dismissal; 3× native text overflowed navigation and the denied-camera page. | Use naturally sized scrolling content, reachable actions, wrapping summaries, and navigation height that fits scaled text. | `4b34902` |
| P2 | Saving `1e100` displayed a capped signed-64-bit integer on native Flutter. | Format whole doubles without converting through an integer. Invalid numeric input still cannot create a schedule. | `be69b4f` |
| P2 | Barcode mode changed visual state while capture still invoked label OCR. | Remove the unsupported mode and describe the working label-photo scan flow accurately. | `e8c9f2d`, `d4688dc` |
| P2 | Privacy text promised account deletion and a broader export than the available account controls. | Describe profile editing, regimen removal, and account-summary copying accurately. | `6e2455d` |

## Final verification

| Check | Result |
|---|---|
| `flutter analyze` | No issues found. |
| Complete `flutter test` suite | 362 passed. Browser-only camera test runs separately. |
| Browser-compatible `flutter test --platform chrome` suites | 272 passed across 49 suites. |
| `FLUTTER_BIN=/path/to/flutter tool/test_browser_camera.sh` | Passed: actual synthetic browser video produces PNG bytes through the production capture implementation; stopping the camera invalidates capture. |
| `node --test test/web_ocr_bridge_test.mjs` | 4 passed: bridge/worker failure and recovery cases. |
| Local Firestore emulator rules suite | 11 passed, including malformed payloads and owner isolation. |
| Recurrence checks with `TZ=America/New_York` | 21 passed, including DST and invalid input. |
| Dedicated native iOS render/interaction run | 25 render cases without framework errors; 30 navigation taps; 25 rapid auth taps produced one submission; 26 screenshots saved. |
| Actual iOS plugins | Vision recognized a generated medication label and rejected corrupt bytes; denied notification permission matched the OS and 100 future doses produced no scheduling exception. |
| `flutter build web` | Passed, including Wasm dry-run compilation. |
| `flutter build ios --simulator --no-codesign` | Passed using the existing ignored local Firebase plist. No service configuration was committed. |

Chrome's selected suites omit tests whose assertions specifically require native haptics, native gallery/OCR method channels, or native glass/navigation appearance. Those cases pass in the complete Flutter suite; dedicated web layout/navigation, report, catalog, persistence, and capture cases run in Chrome. The camera test is opt-in because its runner must provide a synthetic media device and permission flags.

Baseline evidence distinguished product defects from test defects. An offscreen desktop Clear tap, a lazily built picker header assertion, an unscrolled numeric row, a leaked semantics handle, a web XFile fixture name, and a native harness blocked by an OS permission prompt were corrected as harness issues. They are not additional product findings. The initial baseline had 294 passing tests and two failures; the real picker overflow was independently reproduced. Broad baseline Chrome failures included native-only assertions and were not counted as application defects.

Detailed logs, before/after reproductions, simulator screenshots, and `ios_final_render_evidence.json` are retained under `/private/tmp/mediary-hard-test-20261004/artifacts` on the audit host. These are local test artifacts, not generated application files committed to the repository.

## Fix and release plan

1. **Implemented:** recurrence and persistence integrity, account lifecycle, profile schema/health defaults, reporting, real capture/catalog safety, notification authorization/capacity, accessibility, numeric display, and truthful capability/privacy text. Each feature has a separate commit and relevant regressions.
2. **Verified:** analyzer, complete Flutter suite, browser-compatible Chrome suites, browser capture, OCR bridge, emulator rules, native simulator failures, and both builds.
3. **Publish:** push the isolated feature branch to GitHub. A Git push does not deploy the application or Firebase rules.
4. **Hardware verification:** on a connected physical iPhone, exercise real camera and gallery consent/cancellation, focus and label quality, physical rotation, VoiceOver, and background notification banners/sounds.
5. **Authorized notification verification:** grant notification permission on a dedicated device, inspect an unsorted 100-dose regimen's nearest-64 pending queue, and verify foreground/background delivery and replenishment after reopening. iOS pending capacity remains an OS limit; the app must synchronize to replenish the queue as doses leave it.
6. **Service/release verification:** run live browser OCR with external workers and real photos; test offline/CORS/worker-download recovery; confirm production auth/catalog configuration; deploy the checked-in rules and builds through the release workflow and verify authenticated persistence afterward.

## Explicit coverage limits

A physical iPhone was not connected. Simulator testing does not prove hardware camera quality, VoiceOver, notification sound, or background reliability. The real iOS simulator had notification permission denied, so the authorized OS queue limit was verified through unit tests rather than live OS delivery. Browser capture used a synthetic camera; live external OCR-worker downloads remain unverified. Production Firebase rules and hosted apps were not inspected or deployed. These are release verification tasks, not claims of production completion.
