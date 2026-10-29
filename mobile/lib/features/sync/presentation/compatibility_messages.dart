import '../../../l10n/app_localizations.dart';
import '../data/sync_compatibility.dart';

typedef CompatibilityMessages = ({
  String lead,
  String text,
  String title,
  String message,
});

CompatibilityMessages? compatibilityMessagesOf(
  SyncCompatibility compatibility,
  AppLocalizations l10n,
) => switch (compatibility) {
  SyncCompatibility.ok || SyncCompatibility.unreachable => null,
  SyncCompatibility.serverOutdated => (
    lead: l10n.syncServerOutdatedLead,
    text: l10n.syncServerOutdatedText,
    title: l10n.syncServerOutdatedTitle,
    message: l10n.syncServerOutdatedMessage,
  ),
  SyncCompatibility.appOutdated => (
    lead: l10n.syncAppOutdatedLead,
    text: l10n.syncAppOutdatedText,
    title: l10n.syncAppOutdatedTitle,
    message: l10n.syncAppOutdatedMessage,
  ),
};
