import 'package:anchor/core/share/share_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/app_initializer.dart';
import 'core/home_widget/home_widget_service.dart';
import 'core/network/connectivity_provider.dart';
import 'core/notifications/reminder_scheduler.dart';
import 'core/notifications/reminder_tap_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_updater.dart';
import 'features/debug_recorder/data/debug_state_observer.dart';
import 'features/debug_recorder/presentation/debug_recorder_host.dart';
import 'features/note_locks/data/note_lock_secrets.dart';
import 'features/note_locks/presentation/note_lock_session.dart';
import 'features/settings/presentation/controllers/theme_preferences_controller.dart';

void main() async {
  await initializeApp();
  runApp(
    const ProviderScope(observers: [DebugStateObserver()], child: AnchorApp()),
  );
}

class AnchorApp extends ConsumerWidget {
  const AnchorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final density = ref.watch(displayDensityControllerProvider);
    final scheme = ref.watch(colorSchemeControllerProvider);
    final style = ref.watch(appStyleControllerProvider);
    final customTheme = ref.watch(customThemeControllerProvider);

    // Initialize sync manager to listen for connectivity changes
    ref.watch(syncManagerProvider);

    // Keep the Android home-screen widget fed and handle its taps
    ref.watch(homeWidgetSyncProvider);
    ref.watch(homeWidgetLaunchHandlerProvider);

    // Turn "Share to Anchor" into new notes
    ref.watch(shareHandlerProvider);

    // Look for a newer release of the fork when the app starts
    ref.watch(updateControllerProvider);

    // Keep the OS's scheduled reminders in step and handle their taps
    ref.watch(reminderSchedulerProvider);
    ref.watch(reminderTapHandlerProvider);

    // Unlocked notes lock again when the screen turns off. Listened to, not
    // watched: unlocking a note mustn't rebuild the app.
    ref.listen(noteLockSessionProvider, (_, _) {});
    // Keep this device's copy of the PIN and pattern current.
    ref.listen(noteLockSecretsControllerProvider, (_, _) {});

    return MaterialApp.router(
      title: 'Anchor Notes',
      theme: AppTheme.light(density, scheme, style, customTheme),
      darkTheme: AppTheme.dark(density, scheme, style, customTheme),
      themeMode: themeMode,
      routerConfig: router,
      // Debug mode: hold two fingers still for 3 s to film the app.
      builder: (context, child) => DebugRecorderHost(child: child),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
    );
  }
}
