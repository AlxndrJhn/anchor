import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import 'grouped_list.dart';
import 'platform_switch.dart';

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final toggle = PlatformSwitch(
      value: value,
      onChanged: onChanged,
      semanticLabel: label,
    );
    return GroupedListTile(
      label: label,
      subtitle: subtitle,
      icon: icon,
      semanticLabel: value
          ? context.l10n.commonSwitchOn(label)
          : context.l10n.commonSwitchOff(label),
      onTap: onChanged == null ? null : toggle.toggle,
      trailing: ExcludeSemantics(child: toggle),
    );
  }
}
