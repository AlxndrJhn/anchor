import '../../l10n/app_localizations.dart';

enum DisplayDensity {
  standard,
  compact;

  String labelIn(AppLocalizations l10n) => switch (this) {
    DisplayDensity.standard => l10n.densityDefault,
    DisplayDensity.compact => l10n.densityCompact,
  };
}
