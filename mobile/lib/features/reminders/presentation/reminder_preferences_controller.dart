import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../core/storage/storage_keys.dart';
import '../domain/reminder_preferences.dart';

part 'reminder_preferences_controller.g.dart';

@Riverpod(keepAlive: true)
class ReminderPreferencesController extends _$ReminderPreferencesController {
  @override
  ReminderPreferences build() =>
      ref.watch(appBootstrapProvider).reminderPreferences;

  Future<void> setMorning(int minutes) async {
    state = state.copyWith(morning: minutes);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setReminderMinutes(StorageKeys.reminderMorning, minutes);
  }

  Future<void> setAfternoon(int minutes) async {
    state = state.copyWith(afternoon: minutes);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setReminderMinutes(StorageKeys.reminderAfternoon, minutes);
  }

  Future<void> setEvening(int minutes) async {
    state = state.copyWith(evening: minutes);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setReminderMinutes(StorageKeys.reminderEvening, minutes);
  }

  Future<void> setNight(int minutes) async {
    state = state.copyWith(night: minutes);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setReminderMinutes(StorageKeys.reminderNight, minutes);
  }

  Future<void> setWeekStart(int weekday) async {
    state = state.copyWith(weekStart: weekday);
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setReminderWeekStart(weekday);
  }
}
