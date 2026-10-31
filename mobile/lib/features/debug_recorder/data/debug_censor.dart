import 'dart:typed_data';

import 'package:flutter/rendering.dart';

/// How far a censor box reaches past what it hides, in logical pixels:
/// enough for anti-aliasing and the odd descender.
const _bleed = 1.5;

/// Where [root] paints anything personal, in its own coordinates: every
/// line of text, every picture, every camera or platform view. Icons stay,
/// so the film still shows which button was pressed.
///
/// Debug reports leave the phone, so the film shows the app's shape and
/// never what's in it.
List<Rect> findCensoredRects(RenderObject root) {
  final out = <Rect>[];

  void hide(RenderBox box, Iterable<Rect> rects, Rect? clip) {
    final transform = box.getTransformTo(root);
    for (final r in rects) {
      var rect = MatrixUtils.transformRect(transform, r).inflate(_bleed);
      if (clip != null) rect = rect.intersect(clip);
      if (rect.width > 0 && rect.height > 0) out.add(rect);
    }
  }

  void visit(RenderObject node, Rect? clip) {
    if (node is RenderBox) {
      if (!node.hasSize) return;
      final whole = Offset.zero & node.size;
      if (_clips(node)) {
        final bounds = MatrixUtils.transformRect(
          node.getTransformTo(root),
          whole,
        );
        clip = clip == null ? bounds : clip.intersect(bounds);
        if (clip.isEmpty) return;
      }
      final text = _textBoxes(node);
      if (text != null) {
        hide(node, text, clip);
      } else if (_isPicture(node)) {
        hide(node, [whole], clip);
        return; // nothing under a picture shows
      }
    }
    final childClip = clip;
    void child(RenderObject c) {
      if (node.paintsChild(c)) visit(c, childClip);
    }

    // These keep children they don't paint: the routes under an opaque one,
    // the stack's other pages. What they show is what semantics sees.
    if (node is RenderIndexedStack || _isTheater(node)) {
      node.visitChildrenForSemantics(child);
    } else {
      node.visitChildren(child);
    }
  }

  visit(root, null);
  return out;
}

/// Overlay's render object is private; only its name tells it apart.
bool _isTheater(RenderObject node) =>
    node.runtimeType.toString() == '_RenderTheater';

bool _clips(RenderBox node) => switch (node) {
  RenderViewportBase(:final clipBehavior) => clipBehavior != Clip.none,
  RenderClipRect() || RenderClipRRect() || RenderClipOval() => true,
  RenderClipPath() => true,
  _ => false,
};

bool _isPicture(RenderBox node) => switch (node) {
  RenderImage() || TextureBox() => true,
  PlatformViewRenderBox() || RenderDarwinPlatformView() => true,
  RenderDecoratedBox(decoration: BoxDecoration(image: != null)) => true,
  _ => false,
};

/// The lines [node] draws text on, or null when it draws none.
List<Rect>? _textBoxes(RenderBox node) {
  final String plain;
  final List<TextBox> Function(TextSelection) boxes;
  switch (node) {
    case RenderParagraph():
      plain = node.text.toPlainText();
      boxes = node.getBoxesForSelection;
    case RenderEditable():
      plain = node.plainText;
      boxes = node.getBoxesForSelection;
    default:
      return null;
  }
  if (plain.isEmpty || isIconText(plain)) return null;
  try {
    final lines = [
      for (final b in boxes(
        TextSelection(baseOffset: 0, extentOffset: plain.length),
      ))
        b.toRect(),
    ];
    if (lines.isNotEmpty) return lines;
  } catch (_) {
    // Not laid out after all: hide the whole box instead.
  }
  return [Offset.zero & node.size];
}

/// Whether [text] is an icon: glyphs from the private use areas, where
/// icon fonts keep theirs. Emoji and letters are text.
bool isIconText(String text) {
  for (final c in text.runes) {
    final private =
        (c >= 0xE000 && c <= 0xF8FF) || (c >= 0xF0000 && c <= 0x10FFFF);
    if (!private) return false;
  }
  return true;
}

/// Paints [rects], in pixels, solid grey over a frame's RGBA [pixels].
void censorPixels(Uint8List pixels, int width, int height, List<Rect> rects) {
  for (final r in rects) {
    final left = r.left.floor().clamp(0, width);
    final right = r.right.ceil().clamp(0, width);
    final top = r.top.floor().clamp(0, height);
    final bottom = r.bottom.ceil().clamp(0, height);
    for (var y = top; y < bottom; y++) {
      var i = (y * width + left) * 4;
      for (var x = left; x < right; x++, i += 4) {
        pixels[i] = 0x80;
        pixels[i + 1] = 0x80;
        pixels[i + 2] = 0x80;
        pixels[i + 3] = 0xFF;
      }
    }
  }
}
