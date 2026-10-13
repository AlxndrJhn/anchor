import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../motion/haptics.dart';
import '../theme/context_extensions.dart';

class PlatformSwitch extends StatelessWidget {
  const PlatformSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  void _change(bool on) {
    Haptics.selection();
    onChanged?.call(on);
  }

  void toggle() {
    if (onChanged != null) _change(!value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final handler = onChanged == null ? null : _change;
    final isCupertino = context.isCupertino;
    // off-scale: each platform's track.
    final track = isCupertino ? const Size(51, 31) : const Size(52, 32);
    return Semantics(
      label: semanticLabel,
      // The switches pad their track by 4 on each side; only the track
      // takes space in the layout.
      child: SizedBox.fromSize(
        size: track,
        child: OverflowBox(
          maxWidth: track.width + 8,
          maxHeight: track.height + 8,
          child: isCupertino
              ? CupertinoSwitch(
                  value: value,
                  onChanged: handler,
                  activeTrackColor: colors.accentStrong,
                )
              : Switch(
                  value: value,
                  onChanged: handler,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
        ),
      ),
    );
  }
}
