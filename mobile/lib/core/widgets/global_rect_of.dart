import 'package:flutter/widgets.dart';

Rect? globalRectOf(BuildContext? context) {
  final box = context?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
