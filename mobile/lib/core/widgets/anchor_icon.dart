import 'package:flutter/material.dart';

/// The app's icon, as the launcher shows it: a ruled pad with a brass anchor
/// on slate cloth, with a soft shadow.
class AnchorIcon extends StatelessWidget {
  /// The width and height of the icon.
  final double size;

  const AnchorIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: size / 9,
            offset: Offset(0, size / 14),
          ),
        ],
      ),
      // The picture carries its own rounded corners.
      child: Image.asset(
        'assets/icons/anchor_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
