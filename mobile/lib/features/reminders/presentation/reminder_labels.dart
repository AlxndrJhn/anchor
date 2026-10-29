import 'package:intl/intl.dart';

import '../../../core/text/date_formats.dart';
import '../../../l10n/app_localizations.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_dates.dart';
import '../domain/reminder_schedule.dart';
import '../domain/reminder_times.dart';

String reminderDateLabel(DateTime at) =>
    DateFormat.MMMEd(dateLocale).format(at);

String reminderTimeLabel(
  DateTime at,
  DateTime now,
  AppLocalizations l10n, {
  bool showsYear = true,
}) {
  final day = switch (daysFromToday(at, now)) {
    0 => l10n.commonToday,
    1 => l10n.commonTomorrow,
    _ when !showsYear || at.year == now.year => reminderDateLabel(at),
    _ => DateFormat.yMMMEd(dateLocale).format(at),
  };
  return l10n.reminderDayTime(day, clockLabel(at));
}

String repeatLabel(ReminderRecurrence repeat, AppLocalizations l10n) =>
    switch (repeat) {
      ReminderRecurrence.none => l10n.repeatOnce,
      ReminderRecurrence.daily => l10n.repeatDaily,
      ReminderRecurrence.weekly => l10n.repeatWeekly,
      ReminderRecurrence.monthly => l10n.repeatMonthly,
      ReminderRecurrence.yearly => l10n.repeatYearly,
    };

String reminderChipLabel(
  NoteReminder reminder,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final next = nextOccurrence(reminder, from: today);
  final at = next ?? parseWallClock(reminder.remindAt);
  if (at == null) return l10n.reminderTitle;
  final when = next == null
      ? l10n.reminderDayTime(
          DateFormat.MMMd(dateLocale).format(at),
          clockLabel(at),
        )
      : reminderTimeLabel(at, today, l10n, showsYear: false);
  return reminder.recurrence.repeats
      ? l10n.reminderWithRepeat(when, repeatLabel(reminder.recurrence, l10n))
      : when;
}

String reminderSpokenLabel(
  NoteReminder reminder,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final when = reminderChipLabel(reminder, l10n, now: now);
  return isReminderOverdue(reminder, now: now)
      ? l10n.reminderSpokenLate(when)
      : l10n.reminderSpoken(when);
}

String presetLabel(ReminderPreset preset, AppLocalizations l10n) =>
    switch (preset.kind) {
      ReminderPresetKind.laterToday => l10n.reminderLaterToday,
      ReminderPresetKind.tomorrow => l10n.commonTomorrow,
      ReminderPresetKind.nextWeek => l10n.reminderNextWeek,
    };

String presetValueLabel(ReminderPreset preset, AppLocalizations l10n) =>
    preset.kind == ReminderPresetKind.nextWeek
    ? l10n.reminderDayTime(
        DateFormat.E(dateLocale).format(preset.at),
        clockLabel(preset.at),
      )
    : clockLabel(preset.at);

typedef ReminderSummary = ({
  String headline,
  String caption,
  bool isPast,
  bool canSave,
});

ReminderSummary reminderSummary(
  DateTime? at,
  ReminderRecurrence repeat,
  DateTime now,
  AppLocalizations l10n,
) {
  if (at == null) {
    return (
      headline: l10n.reminderNone,
      caption: l10n.reminderPickTime,
      isPast: false,
      canSave: false,
    );
  }
  final next = nextOccurrence(
    NoteReminder(remindAt: toWallClock(at), recurrence: repeat),
    from: now,
  );
  if (next == null) {
    return (
      headline: l10n.reminderTimePassed,
      caption: reminderTimeLabel(at, now, l10n),
      isPast: true,
      canSave: false,
    );
  }
  return (
    headline: reminderTimeLabel(next, now, l10n),
    caption: repeat.repeats
        ? repeatRuleLabel(at, repeat, l10n)
        : reminderCountdownLabel(next, now, l10n),
    isPast: false,
    canSave: true,
  );
}

String reminderCountdownLabel(
  DateTime at,
  DateTime now,
  AppLocalizations l10n,
) {
  final minutes = (at.difference(now).inSeconds / 60).round();
  if (minutes < 60) return l10n.reminderInMinutes(minutes);
  final hours = (minutes / 60).round();
  if (hours < 24) return l10n.reminderInHours(hours);
  final days = daysFromToday(at, now);
  return days == 1 ? l10n.commonTomorrow : l10n.reminderInDays(days);
}

String repeatRuleLabel(
  DateTime at,
  ReminderRecurrence repeat,
  AppLocalizations l10n,
) => switch (repeat) {
  ReminderRecurrence.none => '',
  ReminderRecurrence.daily => l10n.reminderRepeatsDaily,
  ReminderRecurrence.weekly => l10n.reminderRepeatsWeekly(
    DateFormat.EEEE(dateLocale).format(at),
  ),
  ReminderRecurrence.monthly =>
    at.day > 28
        ? l10n.reminderRepeatsMonthlyEnd(at.day)
        : l10n.reminderRepeatsMonthly(at.day),
  ReminderRecurrence.yearly => l10n.reminderRepeatsYearly(
    DateFormat.MMMd(dateLocale).format(at),
  ),
};
