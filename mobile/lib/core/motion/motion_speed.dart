import '../../l10n/app_localizations.dart';

/// How quickly notes, sheets and menus open and close. Only the app's springs
/// and page transitions follow it: scrolling keeps up with the finger, and
/// the small fades and spinners stay as they are.
enum MotionSpeed {
  normal(1),
  fast(0.5);

  const MotionSpeed(this._scale);

  final double _scale;

  /// [duration] at this speed.
  Duration of(Duration duration) => duration * _scale;

  String labelIn(AppLocalizations l10n) => switch (this) {
    MotionSpeed.normal => l10n.animationsNormal,
    MotionSpeed.fast => l10n.animationsFast,
  };
}

/// The chosen speed, for motion code that runs without a `WidgetRef`. Set at
/// launch and whenever Settings changes it.
MotionSpeed motionSpeed = MotionSpeed.normal;
