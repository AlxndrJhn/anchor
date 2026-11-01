/// The times of day the quick reminder choices use, and the day a week
/// starts on.
class ReminderPreferences {
  /// Minutes after midnight.
  final int morning;
  final int afternoon;
  final int evening;
  final int night;

  /// A [DateTime] weekday: "Next week" is the next one of these.
  final int weekStart;

  const ReminderPreferences({
    this.morning = 8 * 60,
    this.afternoon = 13 * 60,
    this.evening = 18 * 60,
    this.night = 22 * 60,
    this.weekStart = DateTime.monday,
  });

  /// The days a week may start on, in the settings' order.
  static const weekStarts = [
    DateTime.monday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  ReminderPreferences copyWith({
    int? morning,
    int? afternoon,
    int? evening,
    int? night,
    int? weekStart,
  }) {
    return ReminderPreferences(
      morning: morning ?? this.morning,
      afternoon: afternoon ?? this.afternoon,
      evening: evening ?? this.evening,
      night: night ?? this.night,
      weekStart: weekStart ?? this.weekStart,
    );
  }
}

/// [day]'s date at [minutes] after midnight.
DateTime atMinutes(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
