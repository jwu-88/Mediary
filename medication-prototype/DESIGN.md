# Mediary — UX Plan

## User Experience Analysis

The product supports people who need a simple, reliable way to understand medications and follow a schedule. The primary needs are fast medication capture, trustworthy identification, clear dose reminders, visible adherence history, and accessible reference information. Because medication data is safety-sensitive, AI results are explicitly labeled with confidence and must be reviewed before a schedule is created.

The core flow is: **scan medication → review AI identification → confirm dosage and frequency → add to calendar → receive reminders → mark each dose taken or skipped**. Users can also search the medication library, open reference details, and add a known medication without scanning.

## Product Interface Planning

- **Today:** next dose, adherence summary, and the day’s dose timeline.
- **Scan:** camera-first capture with clear framing and alternate gallery/barcode inputs.
- **AI Result:** identification confidence, medication facts, safety notice, and editable schedule.
- **Calendar:** monthly adherence overview and selected-day dose history.
- **Library:** medication search, categories, education, and browsable results.
- **Medication Detail:** uses, dosage forms, safety information, and schedule action.
- **Profile:** personal health details, care team, and account shortcuts.
- **Settings:** reminder behavior, privacy, accessibility, and account controls.

## Interaction Logic

The five-item tab bar anchors Today, Calendar, Scan, Library, and Profile. Scan is the central primary action. Calendar dates select a daily detail list; medication cards open details; completed doses use confirmation states. Notification controls use native toggle patterns, and all medication changes require a deliberate confirmation action. Emergency warnings and adverse-event guidance remain visually distinct from routine information.
