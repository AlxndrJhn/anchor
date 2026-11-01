import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/reminders/domain/reminder_preferences.dart';
import 'package:anchor/features/reminders/domain/reminder_times.dart';
import 'package:anchor/features/reminders/presentation/reminder_labels.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  // A Tuesday afternoon.
  final now = DateTime(2026, 8, 18, 15, 2);
  String time(int hour, [int minute = 0]) =>
      clockLabel(DateTime(2026, 1, 1, hour, minute));

  group('the chip', () {
    test('names today and tomorrow, then the weekday', () {
      expect(
        reminderChipLabel(
          const NoteReminder(remindAt: '2026-08-18T18:05'),
          _english,
          now: now,
        ),
        'Today, ${time(18, 5)}',
      );
      expect(
        reminderChipLabel(
          const NoteReminder(remindAt: '2026-08-19T09:00'),
          _english,
          now: now,
        ),
        'Tomorrow, ${time(9)}',
      );
      expect(
        reminderChipLabel(
          const NoteReminder(remindAt: '2026-08-21T09:00'),
          _english,
          now: now,
        ),
        'Fri, Aug 21, ${time(9)}',
      );
    });

    test('a late one shows its date alone and reads as late', () {
      const late = NoteReminder(remindAt: '2026-08-10T17:00');
      expect(isReminderOverdue(late, now: now), isTrue);
      expect(
        reminderChipLabel(late, _english, now: now),
        'Aug 10, ${time(17)}',
      );
      expect(
        reminderSpokenLabel(late, _english, now: now),
        'Overdue reminder: Aug 10, ${time(17)}',
      );
    });

    test('a repeating one names its repeat and is never late', () {
      const weekly = NoteReminder(
        remindAt: '2026-08-10T17:00',
        recurrence: ReminderRecurrence.weekly,
      );
      expect(isReminderOverdue(weekly, now: now), isFalse);
      expect(
        reminderChipLabel(weekly, _english, now: now),
        'Mon, Aug 24, ${time(17)} · Weekly',
      );
      expect(
        reminderSpokenLabel(weekly, _english, now: now),
        startsWith('Reminder: '),
      );
    });

    test('next year leaves out the year, the sheet keeps it', () {
      final at = DateTime(2027, 1, 8, 9);
      expect(
        reminderTimeLabel(at, now, _english, showsYear: false),
        'Fri, Jan 8, ${time(9)}',
      );
      expect(
        reminderTimeLabel(at, now, _english),
        'Fri, Jan 8, 2027, ${time(9)}',
      );
    });
  });

  group('the shortlist', () {
    test('offers each choice on the right day', () {
      final presets = reminderPresets(DateTime(2026, 8, 18, 15, 2));
      expect(presets.map((p) => p.kind), [
        ReminderPresetKind.evening,
        ReminderPresetKind.night,
        ReminderPresetKind.morning,
        ReminderPresetKind.afternoon,
        ReminderPresetKind.weekend,
        ReminderPresetKind.nextWeek,
        ReminderPresetKind.nextMonth,
      ]);
      expect(presets.map((p) => p.at), [
        DateTime(2026, 8, 18, 18),
        DateTime(2026, 8, 18, 22),
        DateTime(2026, 8, 19, 8),
        DateTime(2026, 8, 19, 13),
        DateTime(2026, 8, 22, 8),
        DateTime(2026, 8, 24, 8),
        DateTime(2026, 9, 1, 8),
      ]);
      expect(presets.map((p) => presetValueLabel(p, _english)), [
        time(18),
        time(22),
        time(8),
        time(13),
        'Sat, ${time(8)}',
        'Mon, ${time(8)}',
        'Sep 1, ${time(8)}',
      ]);
    });

    test('offers four times of day, filling up from tomorrow', () {
      List<String> timesOfDay(
        DateTime now, [
        ReminderPreferences times = const ReminderPreferences(),
      ]) => reminderPresets(now, times)
          .where((p) => p.kind.index <= ReminderPresetKind.night.index)
          .map((p) => presetLabel(p, _english))
          .toList();
      expect(timesOfDay(DateTime(2026, 10, 28, 6, 12)), [
        'Later today',
        'This afternoon',
        'This evening',
        'Tonight',
        'Tomorrow morning',
      ]);
      expect(timesOfDay(DateTime(2026, 10, 28, 9, 37)), [
        'This afternoon',
        'This evening',
        'Tonight',
        'Tomorrow morning',
      ]);
      expect(timesOfDay(DateTime(2026, 10, 28, 19)), [
        'Tonight',
        'Tomorrow morning',
        'Tomorrow afternoon',
        'Tomorrow evening',
      ]);
      // Under 20 minutes away is too soon to be worth it.
      expect(timesOfDay(DateTime(2026, 10, 28, 21, 40)).first, 'Tonight');
      expect(timesOfDay(DateTime(2026, 10, 28, 21, 41)), [
        'Tomorrow morning',
        'Tomorrow afternoon',
        'Tomorrow evening',
        'Tomorrow night',
      ]);
      // Before 6:00 the day ahead is tomorrow.
      expect(timesOfDay(DateTime(2026, 10, 28, 5, 59)), [
        'Tomorrow morning',
        'Tomorrow afternoon',
        'Tomorrow evening',
        'Tomorrow night',
      ]);
      expect(
        reminderPresets(DateTime(2026, 10, 28, 5, 59)).first.at,
        DateTime(2026, 10, 28, 8),
      );
      // An early morning starts the day with it.
      expect(
        timesOfDay(
          DateTime(2026, 10, 28, 5, 30),
          const ReminderPreferences(morning: 5 * 60),
        ).first,
        'This afternoon',
      );
      expect(
        tomorrowMorning(DateTime(2026, 10, 28, 6)),
        DateTime(2026, 10, 29, 8),
      );
    });

    test('uses the times of day from the settings', () {
      const times = ReminderPreferences(
        morning: 7 * 60 + 30,
        evening: 21 * 60,
        night: 23 * 60,
      );
      final presets = reminderPresets(DateTime(2026, 8, 18, 19), times);
      expect(presets.take(4).map((p) => p.at), [
        DateTime(2026, 8, 18, 21),
        DateTime(2026, 8, 18, 23),
        DateTime(2026, 8, 19, 7, 30),
        DateTime(2026, 8, 19, 13),
      ]);
    });

    test('starts next week on the chosen day', () {
      DateTime nextWeek(DateTime now, int weekStart) => reminderPresets(
        now,
        ReminderPreferences(weekStart: weekStart),
      ).firstWhere((p) => p.kind == ReminderPresetKind.nextWeek).at;
      // A Tuesday.
      expect(nextWeek(now, DateTime.monday), DateTime(2026, 8, 24, 8));
      expect(nextWeek(now, DateTime.sunday), DateTime(2026, 8, 23, 8));
      expect(nextWeek(now, DateTime.saturday), DateTime(2026, 8, 22, 8));
      // On the day a week starts, the one after.
      expect(
        nextWeek(DateTime(2026, 8, 24, 10), DateTime.monday),
        DateTime(2026, 8, 31, 8),
      );
    });

    test('drops a choice that would repeat an earlier row', () {
      List<ReminderPresetKind> kinds(
        DateTime now, [
        int weekStart = DateTime.monday,
      ]) => reminderPresets(
        now,
        ReminderPreferences(weekStart: weekStart),
      ).map((p) => p.kind).where((k) => k.index > ReminderPresetKind.night.index).toList();
      // Friday and Saturday: the weekend is tomorrow.
      for (final day in [21, 22]) {
        expect(kinds(DateTime(2026, 8, day, 22)), [
          ReminderPresetKind.nextWeek,
          ReminderPresetKind.nextMonth,
        ], reason: 'Aug $day');
      }
      // Sunday: next week is tomorrow.
      expect(kinds(DateTime(2026, 8, 23, 22)), [
        ReminderPresetKind.weekend,
        ReminderPresetKind.nextMonth,
      ]);
      // A week starting on Saturday keeps its name over the weekend.
      expect(kinds(DateTime(2026, 8, 18, 22), DateTime.saturday), [
        ReminderPresetKind.nextWeek,
        ReminderPresetKind.nextMonth,
      ]);
      // The last of the month: next month is tomorrow.
      expect(
        kinds(DateTime(2026, 9, 30, 22)),
        isNot(contains(ReminderPresetKind.nextMonth)),
      );
    });

    test('puts next month on its first day, in the order the days run', () {
      final presets = reminderPresets(DateTime(2026, 10, 30, 22));
      expect(presets.map((p) => p.kind).skip(4), [
        ReminderPresetKind.nextMonth,
        ReminderPresetKind.nextWeek,
      ]);
      expect(presets[4].at, DateTime(2026, 11, 1, 8));
      expect(
        reminderPresets(DateTime(2026, 12, 15)).last.at,
        DateTime(2027, 1, 1, 8),
      );
    });

    test('compares times to the minute', () {
      expect(
        isSameMinute(
          DateTime(2026, 8, 18, 9, 5, 10),
          DateTime(2026, 8, 18, 9, 5, 50),
        ),
        isTrue,
      );
      expect(
        isSameMinute(DateTime(2026, 8, 18, 9, 5), DateTime(2026, 8, 18, 9, 6)),
        isFalse,
      );
    });
  });

  group('the summary', () {
    test('asks for a time when there is none', () {
      final summary = reminderSummary(
        null,
        ReminderRecurrence.none,
        now,
        _english,
      );
      expect(summary.headline, 'No reminder');
      expect(summary.canSave, isFalse);
    });

    test('says when a one-time reminder rings and how soon', () {
      final summary = reminderSummary(
        DateTime(2026, 8, 18, 18, 5),
        ReminderRecurrence.none,
        now,
        _english,
      );
      expect(summary.headline, 'Today, ${time(18, 5)}');
      expect(summary.caption, 'In 3 hours');
      expect(summary.canSave, isTrue);
    });

    test('a time that has passed can not be saved', () {
      final summary = reminderSummary(
        DateTime(2026, 8, 18, 9),
        ReminderRecurrence.none,
        now,
        _english,
      );
      expect(summary.headline, 'This time has already passed');
      expect(summary.isPast, isTrue);
      expect(summary.canSave, isFalse);
    });

    test('a repeat shows the next ring and its rule', () {
      final summary = reminderSummary(
        DateTime(2026, 8, 17, 9),
        ReminderRecurrence.weekly,
        now,
        _english,
      );
      expect(summary.headline, 'Mon, Aug 24, ${time(9)}');
      expect(summary.caption, 'Repeats every Monday');
    });

    test('counts down in minutes, hours, then days', () {
      expect(
        reminderCountdownLabel(
          now.add(const Duration(minutes: 1)),
          now,
          _english,
        ),
        'In 1 minute',
      );
      expect(
        reminderCountdownLabel(
          now.add(const Duration(minutes: 30)),
          now,
          _english,
        ),
        'In 30 minutes',
      );
      expect(
        reminderCountdownLabel(
          now.add(const Duration(hours: 1)),
          now,
          _english,
        ),
        'In 1 hour',
      );
      expect(
        reminderCountdownLabel(DateTime(2026, 8, 19, 18), now, _english),
        'Tomorrow',
      );
      expect(
        reminderCountdownLabel(DateTime(2026, 8, 22, 9), now, _english),
        'In 4 days',
      );
    });

    test('names the monthly day, and the last day for short months', () {
      expect(
        repeatRuleLabel(
          DateTime(2026, 8, 2),
          ReminderRecurrence.monthly,
          _english,
        ),
        'Repeats monthly on day 2',
      );
      expect(
        repeatRuleLabel(
          DateTime(2026, 8, 31),
          ReminderRecurrence.monthly,
          _english,
        ),
        'Repeats monthly on day 31 or the last day',
      );
      expect(
        repeatRuleLabel(
          DateTime(2026, 8, 2),
          ReminderRecurrence.yearly,
          _english,
        ),
        'Repeats every year on Aug 2',
      );
      expect(
        repeatRuleLabel(
          DateTime(2026, 8, 2),
          ReminderRecurrence.daily,
          _english,
        ),
        'Repeats every day',
      );
    });
  });
}
