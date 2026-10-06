# Mediary UI conventions

Use the same visual language and action priorities in web and native routes. Adapt the layout to available space and text size rather than shrinking touch targets or text.

## Actions

Use `AppButton` for named actions and `AppIconButton` for toolbar icons. Keep row/card navigation as rows/cards, selection chips as selections, and the camera shutter as a capture control.

| Role | Use |
| --- | --- |
| Primary | The main next step: save, add, continue, capture, prepare |
| Secondary | An alternative or recovery: choose a photo, retry, clear a search |
| Tertiary | Supporting navigation, cancel, dismiss, Undo |
| Destructive | A confirmed removal |
| Destructive secondary | Removal/sign-out offered beside a primary action |

Named actions share a 48px minimum height, 14px corners and 15px semibold labels. Compact supporting actions and icons have a 44px minimum target. Labels can wrap to two lines; their full text remains available to accessibility services. Keep action wording short enough to remain understandable when text is enlarged.

Callbacks run synchronously so browser camera, clipboard and file pickers retain the click's user activation. Async controls block repeated activation and keep a label visible next to progress. Use `busy` when the screen also tracks the operation. Preserve the draft or review content on failure, show a useful retry message, and re-enable the action.

Use one haptic per native action. If the handler already gives feedback, pass `AppHapticKind.none`. Web and desktop remain silent. Keyboard focus has a visible ring; reduced-motion settings disable control transitions.

## Layout and type

Use `AppSpacing` (4, 8, 12, 16, 24, 32px). Page gutters are 16px below 600px wide and 24px on larger windows. Keep desktop content centered within the established content cap. Use `AppTextStyles.pageTitle`, `sectionTitle`, `body` and `caption` for the corresponding hierarchy; buttons inherit the app font.

Keep one obvious page title, group related fields and information, and put feedback near the action or section it describes. Align section headings and their content. Stack labels/values and action groups when text or width requires it. Make long pages and recovery content scrollable, including short landscape windows and visible keyboards. Keep search focus and clear actions usable as text scales.

## Verification

Check Chrome and native rendering, light/dark/accent themes, keyboard focus and activation, repeated taps, async errors, narrow portrait and landscape, enlarged text, and routes after returning from settings. The shared-control and screen regression tests preserve these behaviors. Visual evidence and run results are recorded under `docs/qa`.
