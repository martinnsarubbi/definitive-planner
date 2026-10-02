/// Absolute deadlines survive navigation, sleep, and app restarts.
int remainingSeconds(Map<String, dynamic> data, DateTime now) {
  final end = data['endsAt'] as int?;
  if (end == null) {
    return data['remaining'] as int? ?? (data['minutes'] as int? ?? 25) * 60;
  }
  return ((end - now.millisecondsSinceEpoch) / 1000).ceil().clamp(0, 86400);
}
