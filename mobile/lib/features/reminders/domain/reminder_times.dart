import '../../notes/domain/note.dart';
import 'reminder_schedule.dart';

bool isReminderOverdue(NoteReminder reminder, {DateTime? now}) =>
    nextOccurrence(reminder, from: now ?? DateTime.now()) == null;

enum ReminderPresetKind {
  laterToday,
  tomorrow,
  weekend,
  nextMonday,
  nextWeek,
  nextMonth,
}

class ReminderPreset {
  const ReminderPreset(this.kind, this.at);

  final ReminderPresetKind kind;
  final DateTime at;
}

/// In the order the days run, dropping "Later today" once it would spill past
/// midnight, and the weekend or Monday on the days they would repeat a row.
List<ReminderPreset> reminderPresets(DateTime now) {
  final later = roundUpToFive(now.add(const Duration(hours: 3)));
  final tomorrow = tomorrowAtNine(now);
  final nextWeek = DateTime(now.year, now.month, now.day + 7, 9);
  // The next Saturday, or Sunday when today is Saturday.
  final weekend = DateTime(
    now.year,
    now.month,
    now.day + (now.weekday == DateTime.saturday ? 1 : 6 - now.weekday % 7),
    9,
  );
  // Always a day ahead, so on a Monday it is the one after.
  final monday = DateTime(now.year, now.month, now.day + 8 - now.weekday, 9);
  // The same day next month, clamped to the end of a short one.
  final lastOfNextMonth = DateTime(now.year, now.month + 2, 0).day;
  final nextMonth = DateTime(
    now.year,
    now.month + 1,
    now.day > lastOfNextMonth ? lastOfNextMonth : now.day,
    9,
  );

  return [
    if (later.day == now.day)
      ReminderPreset(ReminderPresetKind.laterToday, later),
    ReminderPreset(ReminderPresetKind.tomorrow, tomorrow),
    if (!isSameMinute(weekend, tomorrow))
      ReminderPreset(ReminderPresetKind.weekend, weekend),
    if (!isSameMinute(monday, tomorrow) && !isSameMinute(monday, nextWeek))
      ReminderPreset(ReminderPresetKind.nextMonday, monday),
    ReminderPreset(ReminderPresetKind.nextWeek, nextWeek),
    ReminderPreset(ReminderPresetKind.nextMonth, nextMonth),
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
