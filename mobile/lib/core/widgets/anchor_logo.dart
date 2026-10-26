import 'package:flutter/widgets.dart';

import '../theme/context_extensions.dart';

/// The app's icon, as the launcher shows it: a ruled pad with a brass anchor
/// on slate cloth.
class AnchorLogo extends StatelessWidget {
  const AnchorLogo({super.key, required this.size, this.isRaised = true});

  static const double drawer = 32; // off-scale: the app's icon
  static const double about = 44; // off-scale: the app's icon
  static const double heading = 64; // off-scale: the app's icon

  /// The picture drawn by tool/launcher_icon/render-assets.js.
  static const asset = 'assets/icons/anchor_icon.png';

  /// How round the picture's own corners are, against its width.
  static const cornerRatio = 0.22;

  final double size;

  final bool isRaised;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * cornerRatio),
          boxShadow: [...colors.shadowEdge, if (isRaised) ...colors.shadowSm],
        ),
        // The picture carries its own rounded corners.
        child: Image.asset(
          asset,
          width: size,
          height: size,
          cacheWidth: pixels,
          cacheHeight: pixels,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
