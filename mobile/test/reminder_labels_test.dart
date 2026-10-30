import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/features/notes/domain/note.dart';
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
      final presets = reminderPresets(now);
      expect(presets.map((p) => p.kind), ReminderPresetKind.values);
      expect(presets.map((p) => p.at), [
        DateTime(2026, 8, 18, 18, 5),
        DateTime(2026, 8, 19, 9),
        DateTime(2026, 8, 22, 9),
        DateTime(2026, 8, 24, 9),
        DateTime(2026, 8, 25, 9),
        DateTime(2026, 9, 18, 9),
      ]);
      expect(presets.map((p) => presetValueLabel(p, _english)), [
        time(18, 5),
        time(9),
        'Sat, ${time(9)}',
        'Aug 24, ${time(9)}',
        'Tue, ${time(9)}',
        'Sep 18, ${time(9)}',
      ]);
    });

    test('drops later today once it would pass midnight', () {
      final presets = reminderPresets(DateTime(2026, 8, 18, 22));
      expect(presets.first.kind, ReminderPresetKind.tomorrow);
    });

    test('drops the weekend or Monday where they would repeat a row', () {
      List<ReminderPresetKind> kinds(DateTime now) =>
          reminderPresets(now).map((p) => p.kind).toList();
      // Friday and Saturday: the weekend is tomorrow.
      for (final day in [21, 22]) {
        expect(kinds(DateTime(2026, 8, day, 22)), [
          ReminderPresetKind.tomorrow,
          ReminderPresetKind.nextMonday,
          ReminderPresetKind.nextWeek,
          ReminderPresetKind.nextMonth,
        ], reason: 'Aug $day');
      }
      // Sunday: Monday is tomorrow. Monday: next Monday is next week.
      for (final day in [23, 24]) {
        expect(kinds(DateTime(2026, 8, day, 22)), [
          ReminderPresetKind.tomorrow,
          ReminderPresetKind.weekend,
          ReminderPresetKind.nextWeek,
          ReminderPresetKind.nextMonth,
        ], reason: 'Aug $day');
      }
    });

    test('clamps next month to the end of a short one', () {
      final month = reminderPresets(
        DateTime(2026, 1, 31, 22),
      ).firstWhere((p) => p.kind == ReminderPresetKind.nextMonth);
      expect(month.at, DateTime(2026, 2, 28, 9));
    });

    test('rounds up to the next five minutes', () {
      expect(
        roundUpToFive(DateTime(2026, 8, 18, 9, 1)),
        DateTime(2026, 8, 18, 9, 5),
      );
      expect(
        roundUpToFive(DateTime(2026, 8, 18, 9, 56)),
        DateTime(2026, 8, 18, 10),
      );
      expect(
        roundUpToFive(DateTime(2026, 8, 18, 9, 10)),
        DateTime(2026, 8, 18, 9, 10),
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
