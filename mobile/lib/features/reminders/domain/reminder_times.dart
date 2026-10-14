import '../../notes/domain/note.dart';
import 'reminder_schedule.dart';

bool isReminderOverdue(NoteReminder reminder, {DateTime? now}) =>
    nextOccurrence(reminder, from: now ?? DateTime.now()) == null;

enum ReminderPresetKind { laterToday, tomorrow, nextWeek }

class ReminderPreset {
  const ReminderPreset(this.kind, this.at);

  final ReminderPresetKind kind;
  final DateTime at;
}

List<ReminderPreset> reminderPresets(DateTime now) {
  final later = roundUpToFive(now.add(const Duration(hours: 3)));
  return [
    if (later.day == now.day)
      ReminderPreset(ReminderPresetKind.laterToday, later),
    ReminderPreset(ReminderPresetKind.tomorrow, tomorrowAtNine(now)),
    ReminderPreset(
      ReminderPresetKind.nextWeek,
      DateTime(now.year, now.month, now.day + 7, 9),
    ),
  ];
}

DateTime roundUpToFive(DateTime at) {
  final minute = (at.minute / 5).ceil() * 5;
  return DateTime(
    at.year,
    at.month,
    at.day,
    at.hour,
  ).add(Duration(minutes: minute));
}

DateTime tomorrowAtNine(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1, 9);

bool isSameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;
