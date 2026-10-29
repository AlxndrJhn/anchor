import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_bootstrap.dart';
import 'app/bootstrap.dart';
import 'app/router/app_router.dart';
import 'core/motion/springs.dart';
import 'core/theme/app_theme.dart';
import 'features/home_widget/data/home_widget_service.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/reminders/presentation/reminder_tap_handler.dart';
import 'features/settings/presentation/editor_preferences_controller.dart';
import 'features/settings/presentation/theme_preferences_controller.dart';
import 'features/share_target/data/share_target_service.dart';
import 'features/share_target/presentation/share_sheet_app.dart';
import 'features/sync/data/sync_manager.dart';
import 'l10n/l10n.dart';

void main() async {
  final bootstrap = await initializeApp();
  runApp(
    ProviderScope(
      overrides: [appBootstrapProvider.overrideWithValue(bootstrap)],
      child: const AnchorApp(),
    ),
  );
}

/// The sheet Android shows when another app shares to Anchor.
@pragma('vm:entry-point')
Future<void> shareMain() => runShareSheet();

class AnchorApp extends ConsumerStatefulWidget {
  const AnchorApp({super.key});

  @override
  ConsumerState<AnchorApp> createState() => _AnchorAppState();
}

class _AnchorAppState extends ConsumerState<AnchorApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final density = ref.watch(displayDensityControllerProvider);
    final (font, textSize) = ref.watch(
      editorPreferencesControllerProvider.select(
        (editor) => (editor.noteFont, editor.noteTextSize),
      ),
    );

    ref.watch(syncManagerProvider);
    ref.watch(homeWidgetSyncProvider);
    ref.watch(homeWidgetLaunchHandlerProvider);
    ref.watch(reminderSchedulerProvider);
    ref.watch(reminderTapHandlerProvider);
    ref.watch(shareImportProvider);
    ref.watch(shareContextSyncProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      theme: AppTheme.light(density, font, textSize),
      darkTheme: AppTheme.dark(density, font, textSize),
      themeMode: themeMode,
      themeAnimationStyle: isSystemMotionReduced
          ? AnimationStyle.noAnimation
          : null,
      routerConfig: router,
      builder: (context, child) => BackdropGroup(child: child!),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: appLocaleFor,
    );
  }
}
