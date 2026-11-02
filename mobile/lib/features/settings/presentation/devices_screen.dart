import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/text/date_formats.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../core/widgets/pill.dart';
import '../../../l10n/l10n.dart';
import '../../auth/data/repository/auth_repository.dart';
import '../../auth/domain/device_session.dart';

/// The devices signed in as this person, each with its own Sign out.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  late Future<List<DeviceSession>> _sessions = _load();
  String? _signingOut;

  Future<List<DeviceSession>> _load() =>
      ref.read(authRepositoryProvider).listSessions();

  void _reload() {
    final sessions = _load();
    setState(() => _sessions = sessions);
  }

  Future<void> _signOut(DeviceSession session) async {
    final l10n = context.l10n;
    setState(() => _signingOut = session.id);
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.devicesSignedOut(session.device),
          kind: SnackbarKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.devicesSignOutFailed(session.device),
          kind: SnackbarKind.error,
        );
      }
    }
    if (!mounted) return;
    final sessions = _load();
    setState(() {
      _signingOut = null;
      _sessions = sessions;
    });
  }

  Future<void> _signOutOthers() async {
    final l10n = context.l10n;
    await showAnchorDialog(
      context,
      title: l10n.settingsSignOutOthersTitle,
      message: l10n.settingsSignOutOthersMessage,
      confirmLabel: l10n.settingsSignOutOthersConfirm,
      busyLabel: l10n.settingsSigningOut,
      isDanger: true,
      onConfirm: () async {
        try {
          await ref.read(authRepositoryProvider).logoutOtherDevices();
          if (mounted) {
            AppSnackbar.show(
              context,
              l10n.settingsSignOutOthersDone,
              kind: SnackbarKind.success,
            );
          }
        } catch (_) {
          if (mounted) {
            AppSnackbar.show(
              context,
              l10n.settingsSignOutOthersFailed,
              kind: SnackbarKind.error,
            );
          }
        }
      },
    );
    if (mounted) _reload();
  }

  String _when(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return isToday
        ? clockLabel(time)
        : DateFormat.yMMMd(dateLocale).format(time);
  }

  String _use(DeviceSession session) {
    final l10n = context.l10n;
    return session.isCurrent
        ? l10n.devicesSignedIn(_when(session.signedInAt))
        : l10n.devicesSignedInLastActive(
            _when(session.signedInAt),
            _when(session.lastActiveAt),
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.devicesTitle,
      slivers: [
        FutureBuilder<List<DeviceSession>>(
          future: _sessions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverAppEmptyState(
                kind: EmptyStateKind.loadFailed,
                title: l10n.devicesLoadFailed,
                message: l10n.devicesLoadFailedHelp,
                action: AppButton(
                  label: l10n.commonTryAgain,
                  kind: AppButtonKind.secondary,
                  isExpanded: false,
                  onPressed: _reload,
                ),
              );
            }
            final sessions = snapshot.data;
            if (sessions == null) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Spinner()),
              );
            }
            final others = sessions.where((s) => !s.isCurrent).length;
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(16, context.density.space16, 16, 0),
              sliver: SliverList.list(
                children: [
                  GroupedList(
                    children: [
                      for (final session in sessions)
                        GroupedListTile(
                          icon: session.isPhone
                              ? LucideIcons.smartphone
                              : LucideIcons.monitor,
                          label: session.device,
                          subtitle: _use(session),
                          trailing: session.isCurrent
                              ? Pill(label: l10n.devicesThisPhone)
                              : AppButton(
                                  label: l10n.settingsSignOut,
                                  kind: AppButtonKind.secondary,
                                  size: AppButtonSize.small,
                                  isExpanded: false,
                                  isBusy: _signingOut == session.id,
                                  onPressed: _signingOut == null
                                      ? () => _signOut(session)
                                      : null,
                                ),
                        ),
                    ],
                  ),
                  if (others > 1) ...[
                    SizedBox(height: Section.gapOf(context)),
                    GroupedList(
                      children: [
                        GroupedListTile(
                          icon: LucideIcons.logOut,
                          label: l10n.settingsSignOutOthers,
                          isDanger: true,
                          onTap: _signOutOthers,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
