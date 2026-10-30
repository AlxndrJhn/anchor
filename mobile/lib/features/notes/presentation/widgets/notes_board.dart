import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/reorder_animation.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/destruction/strike.dart';
import '../../../../core/widgets/grouped_list.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/sliver_masonry.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/note.dart';
import '../notes_list_controller.dart';
import 'card_body.dart';

class NotesBoard extends StatelessWidget {
  const NotesBoard({
    super.key,
    required this.groups,
    required this.layout,
    required this.generation,
    required this.contentKey,
    required this.cardBuilder,
    this.header = const [],
    this.empty,
    this.onToggleFold,
  });

  final List<NoteGroup> groups;
  final CardLayout layout;

  /// Changes when the list's content changes; cards slide only then.
  final Object generation;

  /// The scroll view the cards are measured in.
  final GlobalKey contentKey;

  /// Builds a note's card, keyed by `ValueKey(note.id)`.
  final Widget Function(Note note, int index) cardBuilder;

  final List<Widget> header;
  final Widget? empty;
  final VoidCallback? onToggleFold;

  @override
  Widget build(BuildContext context) {
    final density = context.density;
    final slivers = <Widget>[
      ...header,
      if (empty case final empty?)
        SliverToBoxAdapter(child: empty)
      else
        for (final group in groups)
          if (group.labelIn(context.l10n) case final label?) ...[
            SliverToBoxAdapter(
              child: _GroupHeader(
                group: group,
                label: label,
                padding: EdgeInsets.fromLTRB(
                  16 + 12,
                  identical(group, groups.first)
                      ? density.space8
                      : density.space24,
                  16 + 12,
                  density.space8,
                ),
                onToggleFold: group.canFold ? onToggleFold : null,
              ),
            ),
            if (!group.isFolded)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _cards(context, group.notes),
              ),
          ] else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, density.space8, 16, 0),
              sliver: _cards(context, group.notes),
            ),
    ];
    return ReorderAnimationScope(
      generation: generation,
      contentKey: contentKey,
      child: SliverMainAxisGroup(slivers: slivers),
    );
  }

  Widget _cards(BuildContext context, List<Note> notes) {
    final count = notes.length;
    final gap = context.density.space12;
    // Cards are keyed by note, so one keeps its state when the order changes
    // under it, as while a note is dragged.
    int? indexOf(Key key) {
      final index = notes.indexWhere((note) => ValueKey(note.id) == key);
      return index < 0 ? null : index;
    }

    return switch (layout) {
      CardLayout.masonry => SliverMasonry(
        itemKeys: [for (final note in notes) note.id],
        // After a delete the other cards keep their columns: only those
        // below the gap move up into it.
        keepColumns: isCardStrikeArmed,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        itemBuilder: (context, i) => cardBuilder(notes[i], i),
        findChildIndexCallback: indexOf,
      ),
      CardLayout.grid => SliverList.separated(
        itemCount: (count + 1) ~/ 2,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (context, row) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cardBuilder(notes[row * 2], row * 2)),
              SizedBox(width: gap),
              Expanded(
                child: row * 2 + 1 < count
                    ? cardBuilder(notes[row * 2 + 1], row * 2 + 1)
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
      CardLayout.list => SliverList.separated(
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (context, i) => cardBuilder(notes[i], i),
        findItemIndexCallback: indexOf,
      ),
    };
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.label,
    required this.padding,
    this.onToggleFold,
  });

  final NoteGroup group;
  final String label;

  /// Includes the gap above the cards.
  final EdgeInsets padding;
  final VoidCallback? onToggleFold;

  @override
  Widget build(BuildContext context) {
    final onToggleFold = this.onToggleFold;
    final spring = Spring.snappy;
    final header = SectionHeader(
      label,
      icon: switch (group.kind) {
        NoteGroupKind.pinned => LucideIcons.pin,
        NoteGroupKind.archived => LucideIcons.archive,
        NoteGroupKind.pictures => LucideIcons.images,
        NoteGroupKind.all || NoteGroupKind.others => null,
      },
      count: group.notes.length,
      padding: padding,
      trailing: onToggleFold == null
          ? null
          : AnimatedRotation(
              turns: group.isFolded ? -0.25 : 0,
              duration: context.motion(spring.duration),
              curve: spring.curve,
              child: Icon(
                LucideIcons.chevronDown,
                size: AnchorTokens.sizeIconSmall,
                color: context.anchor.appMuted,
              ),
            ),
    );
    if (onToggleFold == null) return header;
    return Pressable(
      style: PressStyle.plain,
      onTap: () {
        Haptics.selection();
        onToggleFold();
      },
      child: Semantics(
        expanded: !group.isFolded,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AnchorTokens.sizeTargetTouch,
          ),
          child: Align(alignment: Alignment.bottomCenter, child: header),
        ),
      ),
    );
  }
}
