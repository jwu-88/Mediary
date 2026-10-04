import '../time_formatting.dart';
import 'mediary_models.dart';
import 'schedule_occurrence_generator.dart';

/// Treat legacy and deterministic IDs for one schedule slot as one dose.
/// Different schedules, dates, times, and medications remain separate.
List<DoseLogRecord> uniqueDoseOccurrences(Iterable<DoseLogRecord> doses) {
  final bySlot = <String, DoseLogRecord>{};
  for (final dose in doses) {
    final key = dose.scheduleId.isEmpty
        ? dose.id
        : '${dose.medicationId}|${dose.scheduleId}|${dose.localDate}|'
              '${MedicationTime.fromLocalTime(dose.localTime).localTime}';
    final previous = bySlot[key];
    if (previous == null || _prefer(dose, previous)) bySlot[key] = dose;
  }
  return bySlot.values.toList(growable: false);
}

bool _prefer(DoseLogRecord candidate, DoseLogRecord previous) {
  int statePriority(String status) => switch (status) {
    'cancelled' => 5,
    'taken' => 4,
    'missed' || 'skipped' => 3,
    'snoozed' => 2,
    _ => 1,
  };
  final stateDifference =
      statePriority(candidate.status) - statePriority(previous.status);
  if (stateDifference != 0) return stateDifference > 0;
  final candidateUpdated = candidate.updatedAt ?? candidate.createdAt;
  final previousUpdated = previous.updatedAt ?? previous.createdAt;
  if (candidateUpdated != previousUpdated) {
    if (candidateUpdated == null) return false;
    if (previousUpdated == null) return true;
    return candidateUpdated.isAfter(previousUpdated);
  }
  final canonicalId = ScheduleOccurrenceGenerator.deterministicOccurrenceId(
    candidate.scheduleId,
    localDate: candidate.localDate,
    localTime: candidate.localTime,
  );
  if (candidate.id == canonicalId) return true;
  if (previous.id == canonicalId) return false;
  return candidate.id.compareTo(previous.id) < 0;
}
