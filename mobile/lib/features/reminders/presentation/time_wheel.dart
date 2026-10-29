import 'package:flutter/cupertino.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';

class TimeWheel extends StatelessWidget {
  const TimeWheel({super.key, required this.at, required this.onChanged});

  final DateTime at;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final start = DateTime(
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute - at.minute % 5,
    );
    return SizedBox(
      height: 180, // off-scale: five rows of the time wheel
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: context.isDark ? Brightness.dark : Brightness.light,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: AppTypography.row.tabular
                .withSize(AppTypography.sheetTitle.fontSize!)
                .copyWith(color: colors.appText),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: start,
          minuteInterval: 5,
          use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          onDateTimeChanged: onChanged,
        ),
      ),
    );
  }
}
