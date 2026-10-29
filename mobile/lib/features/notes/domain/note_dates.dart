bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [now] to [date], unaffected by daylight saving.
int daysFromToday(DateTime date, DateTime now) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

/// Minutes since [at] while under an hour, 0 for anything under a minute.
int? minutesAgo(DateTime at, {DateTime? now}) {
  final minutes = (now ?? DateTime.now()).difference(at).inMinutes;
  if (minutes < 1) return 0;
  return minutes < 60 ? minutes : null;
}

String firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;

String durationLabel(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

const int trashDays = 30;

const int historyDays = 90;
