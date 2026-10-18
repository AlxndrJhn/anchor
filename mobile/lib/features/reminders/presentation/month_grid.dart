import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/text/date_formats.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.now,
    required this.onDay,
    required this.onMonth,
  });

  final DateTime month;
  final DateTime? selected;
  final DateTime now;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final firstWeekday = material.firstDayOfWeekIndex;
    final first = DateTime(month.year, month.month);
    final start = first.subtract(
      Duration(days: (first.weekday % 7 - firstWeekday) % 7),
    );
    final today = DateTime(now.year, now.month, now.day);
    final canGoBack = DateTime(now.year, now.month).isBefore(first);
    Widget arrow(IconData icon, String label, DateTime? to) => BarButton(
      icon: icon,
      label: label,
      size: BarButtonSize.medium,
      onPressed: to == null
          ? null
          : () {
              Haptics.selection();
              onMonth(to);
            },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            arrow(
              LucideIcons.chevronLeft,
              l10n.monthPrevious,
              canGoBack ? DateTime(month.year, month.month - 1) : null,
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM(dateLocale).format(month),
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.appText,
                ),
              ),
            ),
            arrow(
              LucideIcons.chevronRight,
              l10n.monthNext,
              DateTime(month.year, month.month + 1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    material.narrowWeekdays[(firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.appMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = DateTime(
                        start.year,
                        start.month,
                        start.day + row * 7 + col,
                      );
                      final isPast = day.isBefore(today);
                      final isToday = day == today;
                      final isOn =
                          selected != null &&
                          day.year == selected!.year &&
                          day.month == selected!.month &&
                          day.day == selected!.day;
                      final outside = day.month != month.month;
                      final foreground = isOn
                          ? colors.appSurface
                          : isPast || outside
                          ? colors.appMuted
                          : isToday
                          ? colors.accentInk
                          : colors.appText;
                      return Center(
                        child: Pressable(
                          style: PressStyle.barButton,
                          onTap: isPast ? null : () => onDay(day),
                          semanticLabel: DateFormat.MMMMEEEEd(
                            dateLocale,
                          ).format(day),
                          selected: isOn,
                          child: AnimatedContainer(
                            duration: context.motion(
                              AnchorTokens.motionDurationHover,
                            ),
                            width: AnchorTokens.sizeControlMedium,
                            height: AnchorTokens.sizeControlMedium,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOn ? colors.appText : null,
                              border: isToday && !isOn
                                  ? Border.all(
                                      color: colors.accentStrong,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Text(
                              '${day.day}',
                              style: AppTypography.secondary.tabular.copyWith(
                                fontWeight: isOn || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: foreground,
                                decoration: isPast
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: colors.appMuted.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
