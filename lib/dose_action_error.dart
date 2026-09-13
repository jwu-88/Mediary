String doseActionErrorMessage(Object error, {required String action}) {
  final details = error.toString().toLowerCase();
  if (details.contains('permission-denied') ||
      details.contains('missing or insufficient permissions')) {
    return 'Your session cannot update this dose. Sign in again and retry.';
  }
  if (details.contains('not-found') || details.contains('does not exist')) {
    return 'This dose is already gone. Refreshing the schedule will update the list.';
  }
  if (details.contains('network') || details.contains('unavailable')) {
    return 'You appear to be offline. Reconnect and try again.';
  }
  return action == 'remove'
      ? 'Could not remove this dose. Please try again.'
      : 'Could not update this dose. Please try again.';
}
