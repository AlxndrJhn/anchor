import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_typography.dart';

/// Its box runs from the top of the capitals to the baseline; glyphs still
/// paint outside it.
class CapHeightText extends StatelessWidget {
  const CapHeightText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  static double capHeightOf(BuildContext context, TextStyle? style) {
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final size = MediaQuery.textScalerOf(context).scale(merged.fontSize ?? 14);
    return AppTypography.capHeightOf(merged.fontFamily) * size;
  }

  @override
  Widget build(BuildContext context) {
    return _CapHeightBox(
      capHeight: capHeightOf(context, style),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        semanticsLabel: semanticsLabel,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CapHeightBox extends SingleChildRenderObjectWidget {
  const _CapHeightBox({required this.capHeight, required super.child});

  final double capHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCapHeightBox(capHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCapHeightBox renderObject,
  ) {
    renderObject.capHeight = capHeight;
  }
}

class _RenderCapHeightBox extends RenderShiftedBox {
  _RenderCapHeightBox(this._capHeight) : super(null);

  double _capHeight;
  set capHeight(double value) {
    if (value == _capHeight) return;
    _capHeight = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      );

  Size _sizeFor(BoxConstraints constraints, Size child) =>
      constraints.constrain(Size(child.width, _capHeight));

  double _baselineIn(Size size) => (size.height + _capHeight) / 2;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size(0, _capHeight));
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baselineIn(getDryLayout(constraints));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _capHeight));
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    final childBaseline =
        child.getDistanceToBaseline(TextBaseline.alphabetic) ??
        child.size.height;
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      _baselineIn(size) - childBaseline,
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _baselineIn(size);

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(double.infinity) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(double.infinity) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => _capHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _capHeight;
}
