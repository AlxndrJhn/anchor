import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/frosted_glass.dart';
import '../../../../core/widgets/page_settled.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/note.dart';
import '../../domain/note_dates.dart';
import '../note_labels.dart';
import 'note_surface.dart';

double _buttonsWidth(BuildContext context) {
  double width(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.row.copyWith(fontWeight: FontWeight.w600),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  const deletePadding = 16.0 * 2;
  const restorePadding = 24.0 * 2;
  const gap = 8.0;
  const spare = 8.0;
  return width(context.l10n.actionDeletePermanently) +
      deletePadding +
      gap +
      AnchorTokens.sizeIconMedium +
      gap +
      width(context.l10n.actionRestore) +
      restorePadding +
      spare;
}

class ReadOnlyBottomBar extends StatelessWidget {
  const ReadOnlyBottomBar({
    super.key,
    required this.note,
    required this.appearance,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final Note note;
  final NoteAppearance appearance;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  static final _filter = frostedGlassFilter(20);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AnchorTokens.radius4xl);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: context.anchor.shadowFloating,
        ),
        child: PageSettledBuilder(
          builder: (context, settled) => ClipRRect(
            borderRadius: radius,
            child: BackdropFilter.grouped(
              enabled: settled,
              filter: _filter,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: context.density.space8,
                ),
                decoration: BoxDecoration(
                  color: appearance.colors.surface.withValues(
                    alpha: settled ? 0.88 : 1,
                  ),
                  borderRadius: radius,
                  border: Border.all(
                    color: appearance.colors.border.withValues(alpha: 0.8),
                  ),
                ),
                child: _content(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final trashed = note.isTrashed;
    final l10n = context.l10n;
    final message = _message(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: context.density.space8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            spacing: 12,
            children: [
              if (trashed)
                const _BarIcon(LucideIcons.trash2)
              else if (note.sharedBy != null)
                PersonAvatar(
                  name: note.sharedBy!.name,
                  imageUrl: note.sharedBy!.profileImage,
                  size: PersonAvatar.bar,
                )
              else
                const _BarIcon(LucideIcons.eye),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: AppTypography.secondary.copyWith(
                    color: appearance.colors.muted,
                  ),
                  child: message,
                ),
              ),
            ],
          ),
        ),
        if (trashed)
          LayoutBuilder(
            builder: (context, box) {
              final restore = AppButton(
                label: l10n.actionRestore,
                icon: LucideIcons.rotateCcw,
                onPressed: onRestore,
              );
              final fits = box.maxWidth >= _buttonsWidth(context);
              return fits
                  ? Row(
                      spacing: 8,
                      children: [
                        AppButton(
                          label: l10n.actionDeletePermanently,
                          kind: AppButtonKind.dangerText,
                          isExpanded: false,
                          onPressed: onDeleteForever,
                        ),
                        Expanded(child: restore),
                      ],
                    )
                  : Column(
                      spacing: 8,
                      children: [
                        restore,
                        AppButton(
                          label: l10n.actionDeletePermanently,
                          kind: AppButtonKind.dangerText,
                          onPressed: onDeleteForever,
                        ),
                      ],
                    );
            },
          ),
      ],
    );
  }

  Widget _message(BuildContext context) {
    final l10n = context.l10n;
    return note.isTrashed
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${l10n.readOnlyInTrash} ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.anchor.appText,
                  ),
                ),
                TextSpan(text: trashDeletionLabel(note.updatedAt, l10n)),
              ],
            ),
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${l10n.readOnlyViewOnly} ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.anchor.appText,
                  ),
                ),
                TextSpan(
                  text: note.sharedBy == null
                      ? l10n.readOnlyOwnerEdits
                      : l10n.readOnlySharedBy(firstNameOf(note.sharedBy!.name)),
                ),
              ],
            ),
          );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = context.anchor.appText;
    return Container(
      width: PersonAvatar.bar,
      height: PersonAvatar.bar,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: AnchorTokens.sizeIconSmall, color: color),
    );
  }
}
