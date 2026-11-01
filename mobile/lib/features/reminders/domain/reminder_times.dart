import 'dart:math';

import '../../notes/domain/note.dart';
import 'reminder_preferences.dart';
import 'reminder_schedule.dart';

bool isReminderOverdue(NoteReminder reminder, {DateTime? now}) =>
    nextOccurrence(reminder, from: now ?? DateTime.now()) == null;

/// The times of day come first, in the order they run.
enum ReminderPresetKind {
  morning,
  afternoon,
  evening,
  night,
  weekend,
  nextWeek,
  nextMonth,
}

class ReminderPreset {
  const ReminderPreset(this.kind, this.at, {this.isTomorrow = false});

  final ReminderPresetKind kind;
  final DateTime at;

  /// A time of day that is tomorrow's, as the whole day ahead is in the
  /// small hours.
  final bool isTomorrow;
}

/// When the day begins, unless the morning time comes first.
const _dayStart = 6 * 60;

/// How soon a choice may be: one any closer is not worth a reminder.
const _soonest = Duration(minutes: 20);

/// How many times of day the list offers: what is left of today, and the
/// rest from tomorrow.
const _timesOfDay = 4;

/// Whether [now] is in the small hours, still belonging to yesterday.
bool isBeforeDawn(
  DateTime now, [
  ReminderPreferences times = const ReminderPreferences(),
]) => now.isBefore(
  atMinutes(now, times.morning < _dayStart ? times.morning : _dayStart),
);

/// In the order the days run: what is left of today's morning, afternoon,
/// evening and night from [times], each until it is under 20 minutes away,
/// then tomorrow's, always with its morning, until there are four. Before
/// the day begins, the night still belongs to yesterday and the day ahead is
/// tomorrow. A choice that would repeat an earlier row's time is dropped,
/// the weekend giving way to a week that starts on it.
List<ReminderPreset> reminderPresets(
  DateTime now, [
  ReminderPreferences times = const ReminderPreferences(),
]) {
  // The next Saturday, or Sunday when today is Saturday.
  final weekend = DateTime(
    now.year,
    now.month,
    now.day + (now.weekday == DateTime.saturday ? 1 : 6 - now.weekday % 7),
  );
  // The next start of a week, always a day ahead.
  final toWeekStart = (times.weekStart - now.weekday) % 7;
  final nextWeek = DateTime(
    now.year,
    now.month,
    now.day + (toWeekStart == 0 ? 7 : toWeekStart),
  );

  final dayTimes = {
    ReminderPresetKind.morning: times.morning,
    ReminderPresetKind.afternoon: times.afternoon,
    ReminderPresetKind.evening: times.evening,
    ReminderPresetKind.night: times.night,
  };
  List<ReminderPreset> timesOfDay(DateTime day, {required bool isTomorrow}) => [
    for (final MapEntry(:key, :value) in dayTimes.entries)
      if (!atMinutes(day, value).isBefore(now.add(_soonest)))
        ReminderPreset(key, atMinutes(day, value), isTomorrow: isTomorrow),
  ];
  final beforeDawn = isBeforeDawn(now, times);
  final today = beforeDawn
      ? <ReminderPreset>[]
      : timesOfDay(now, isTomorrow: false);
  final tomorrow = timesOfDay(
    beforeDawn ? now : DateTime(now.year, now.month, now.day + 1),
    isTomorrow: true,
  );

  final presets = [
    ...today,
    ...tomorrow.take(max(1, _timesOfDay - today.length)),
  ];
  void add(ReminderPresetKind kind, DateTime at) {
    if (!presets.any((p) => isSameMinute(p.at, at))) {
      presets.add(ReminderPreset(kind, at));
    }
  }

  add(ReminderPresetKind.nextWeek, atMinutes(nextWeek, times.morning));
  add(ReminderPresetKind.weekend, atMinutes(weekend, times.morning));
  add(
    ReminderPresetKind.nextMonth,
    atMinutes(DateTime(now.year, now.month + 1), times.morning),
  );
  return presets..sort((a, b) => a.at.compareTo(b.at));
}

/// The next morning: today's in the small hours.
DateTime tomorrowMorning(
  DateTime now, [
  ReminderPreferences times = const ReminderPreferences(),
]) => atMinutes(
  isBeforeDawn(now, times) ? now : DateTime(now.year, now.month, now.day + 1),
  times.morning,
);

bool isSameMinute(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;
