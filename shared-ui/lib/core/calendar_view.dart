import 'model.dart';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
DateTime calendarWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday % 7);
String calendarClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// Split events at local midnights. An exclusive midnight end does not occupy
/// the next day. Bound the agenda window, including very long all-day events.
Map<DateTime, List<Json>> calendarAgenda(
  List<Json> events,
  DateTime from,
  DateTime until,
) {
  final result = <DateTime, List<Json>>{};
  for (final event in events) {
    final data = object(event['data']);
    final start = DateTime.tryParse(text(data['starts_at']))?.toLocal();
    final end = DateTime.tryParse(text(data['ends_at']))?.toLocal() ?? start;
    if (start == null || end == null || end.isBefore(start)) continue;
    var day = calendarDay(start.isBefore(from) ? from : start);
    while (day.isBefore(until)) {
      final next = DateTime(day.year, day.month, day.day + 1);
      if (end.isBefore(day) ||
          end.isAtSameMomentAs(day) && !start.isAtSameMomentAs(end))
        break;
      if (start.isBefore(next) &&
          (end.isAfter(day) || start.isAtSameMomentAs(day))) {
        result.putIfAbsent(day, () => []).add({
          ...event,
          'local_start': start,
          'local_end': end,
          'continues_before': start.isBefore(day),
          'continues_after': end.isAfter(next),
        });
      }
      day = next;
    }
  }
  for (final group in result.values) {
    group.sort(
      (a, b) => (a['local_start'] as DateTime).compareTo(
        b['local_start'] as DateTime,
      ),
    );
  }
  return Map.fromEntries(
    result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
