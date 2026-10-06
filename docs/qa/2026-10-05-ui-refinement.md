# Web and mobile UI refinement

Date: October 5, 2026. Branch: `codex/ui-consistency`, based on the completed hard-test fixes. Three agents worked in separate copies; changes were integrated in a managed worktree. The primary checkout and other agents' devices/browser sessions were not changed.

## Implemented

- Shared named/icon controls, primary/secondary/tertiary/destructive priorities, consistent touch sizes, corners, type, hover/focus feedback, native haptics and reduced motion.
- Labels remain readable while actions run; repeated async activation is blocked. Browser camera/file/clipboard callbacks keep their original click activation.
- Consistent page gutters, section headings, form borders, cards, dialog treatment and back controls. Search grows with enlarged text and retains focus after clearing.
- Refined sign-in, verification, dashboard, calendar, scanner, medication library/picker/details, account, settings, reports, legal/support and schedule/time routes.
- Enlarged phone dose rows show full medication, dose, time and status instead of squeezing table columns. Narrow/large-text action groups, settings values and health summaries stack; recovery dialogs scroll.
- Dose confirmations and Undo stay beside the relevant section. Scan persistence, calendar saves, bookmarks, summary preparation, copying, support email and current-label launch failures show retryable feedback without discarding drafts/content. Scan retries preserve their record identity.

## Feature commits

| Commit | Change |
| --- | --- |
| `78e132e` | Shared controls and design tokens |
| `6f1ccba` | Sign-in and scheduling actions |
| `8867853` | Account, settings and reports |
| `6f16c2c` | Dashboard/calendar readability |
| `4670ec8` | Medication workflows and retry feedback |

## Verification

| Check | Result |
| --- | --- |
| Formatting | All Dart source/tests formatted; final check has no changes |
| Flutter analyzer | No issues |
| Complete Flutter test suite | 410 passed |
| Final core Chrome suites | 31 passed: controls, auth, external actions, denied-camera dialog, profile actions and responsive routes |
| Final incremental Chrome suites | 14 passed: scan/bookmark retry and populated enlarged-text dose rows |
| Additional focused dashboard/calendar coverage | 52 passed per platform, including 320/430px at 2×/3× text |
| Dedicated iOS simulator | Build succeeded; 26 native checks passed; 37 screenshots exported |
| Visual review | 56 Chrome captures across seven main screens, 430/1280px, light/dark, 1×/2×; representative native screens and 3× recovery/edit/action states inspected |

Native rendering and clipboard were real. Account/catalog/write callbacks used synthetic data. The iOS checks used a dedicated iPhone SE simulator; no physical iPhone was connected. These checks verify application UI and recovery behavior, not production services or hardware camera/notification delivery. The earlier hard-test report retains those release-verification limits.

The initial full integration run exposed old tests tapping lazy/offscreen controls under the bottom bar. Those tests now scroll before assertions/taps. The denied-camera 3× dialog overflow, undersized scan fields, truncated enlarged dose information and missing failure notices were product issues and were fixed. The first native run's lone failure was a lazy picker-row tap in the harness; the corrected run passed all 26 checks.

## Selected screenshots

[Chrome desktop dashboard](ui-consistency/chrome-dashboard-desktop.png) · [Chrome mobile calendar, dark](ui-consistency/chrome-calendar-mobile-dark.png) · [Chrome account](ui-consistency/chrome-profile-mobile.png) · [Chrome settings, dark](ui-consistency/chrome-settings-mobile-dark.png) · [Chrome report, dark](ui-consistency/chrome-report-desktop-dark.png)

[iOS scan review](ui-consistency/ios-scan-review.png) · [iOS selected picker, dark](ui-consistency/ios-picker-dark.png) · [iOS account editing](ui-consistency/ios-profile-edit.png)

Shared implementation conventions: [UI guide](../design/ui-consistency.md).
