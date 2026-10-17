import 'dart:convert';

import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/editor/checklist_fold.dart';
import 'package:anchor/features/notes/presentation/editor/document_lines.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

String checklist(List<(String, String)> items) => jsonEncode({
  'ops': [
    for (final (text, state) in items) ...[
      {'insert': text},
      {
        'insert': '\n',
        'attributes': {'list': state},
      },
    ],
  ],
});

String nestedChecklist(List<(String, String, int)> items) => jsonEncode({
  'ops': [
    for (final (text, state, indent) in items) ...[
      {'insert': text},
      {
        'insert': '\n',
        'attributes': {'list': state, if (indent > 0) 'indent': indent},
      },
    ],
  ],
});

final _plain = AnchorColors.light.notes['none']!;

final palette = EditorPalette(
  muted: _plain.muted,
  surface: _plain.surface,
  border: _plain.border,
  background: _plain.bg,
  highlightFill: (name) => AnchorColors.light.highlights[name]!.fill,
  highlightInk: (name) => AnchorColors.light.highlights[name]!.ink!,
);

Widget wrap(Widget Function(ScrollController scroll) builder) {
  return MaterialApp(
    localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
    home: Scaffold(body: _Scroller(builder: builder)),
  );
}

class _Scroller extends StatefulWidget {
  const _Scroller({required this.builder});

  final Widget Function(ScrollController scroll) builder;

  @override
  State<_Scroller> createState() => _ScrollerState();
}

class _ScrollerState extends State<_Scroller> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: _scroll,
    child: widget.builder(_scroll),
  );
}

void main() {
  Future<(RichTextEditorState, FocusNode)> pumpEditor(
    WidgetTester tester, {
    required String content,
    bool canEdit = true,
    bool sortChecklistItems = false,
    bool isCheckedFolded = false,
    Rect? visibleArea,
    VoidCallback? onChanged,
  }) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      wrap(
        (scroll) => RichTextEditor(
          initialContent: content,
          focusNode: focusNode,
          canEdit: canEdit,
          sortChecklistItems: sortChecklistItems,
          isCheckedFolded: isCheckedFolded,
          visibleArea: visibleArea == null ? null : () => visibleArea,
          onChanged: onChanged,
          scrollController: scroll,
          palette: palette,
        ),
      ),
    );
    await tester.pump();
    final state = tester.state<RichTextEditorState>(
      find.byType(RichTextEditor),
    );
    return (state, focusNode);
  }

  Finder checkboxSlot(int index) => find
      .byWidgetPredicate((w) => w is Semantics && w.properties.checked != null)
      .at(index);

  List<(String, String?)> lines(RichTextEditorState state) {
    final doc = state.controller.document;
    final text = doc.toPlainText();
    return [
      for (final line in parseDocumentLines(doc))
        (
          text.substring(line.startOffset, line.startOffset + line.length - 1),
          line.listType,
        ),
    ];
  }

  List<(String, String?, int)> nestedLines(RichTextEditorState state) {
    final doc = state.controller.document;
    final text = doc.toPlainText();
    return [
      for (final line in parseDocumentLines(doc))
        (
          text.substring(line.startOffset, line.startOffset + line.length - 1),
          line.listType,
          line.indent,
        ),
    ];
  }

  Future<TestGesture> startDrag(WidgetTester tester, Finder slot) async {
    final gesture = await tester.startGesture(tester.getCenter(slot));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    return gesture;
  }

  Future<void> dragTo(
    WidgetTester tester,
    TestGesture gesture,
    Offset target,
  ) async {
    await gesture.moveTo(target);
    await tester.pump();
  }

  const abcd = [
    ('a', 'unchecked'),
    ('b', 'unchecked'),
    ('c', 'unchecked'),
    ('d', 'unchecked'),
  ];

  testWidgets('holding the box lifts the item, dims it and shows its ghost', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await tester.startGesture(
      tester.getCenter(checkboxSlot(1)),
    );
    await tester.pump(
      AnchorTokens.motionDurationLongPress - const Duration(milliseconds: 20),
    );
    expect(state.checklistDrag.isDragging, isFalse);
    await tester.pump(const Duration(milliseconds: 40));
    expect(state.checklistDrag.isDragging, isTrue);
    expect(state.checklistDrag.text, 'b');
    expect(
      state.checklistDrag.dragged.value,
      const TextRange(start: 2, end: 3),
    );

    final ghost = tester.getRect(find.byKey(const Key('checklist-drag-ghost')));
    final finger = tester.getCenter(checkboxSlot(1));
    expect(ghost.height, AnchorTokens.sizeControlSmall);
    expect(ghost.left, finger.dx - 24 < 8 ? 8 : finger.dx - 24);
    expect(ghost.top, finger.dy - 56);
    final bText = find.descendant(
      of: find.byType(QuillEditor),
      matching: find.text('b', findRichText: true),
    );
    expect(tester.widget<RichText>(bText).text.toPlainText(), 'b');

    await gesture.up();
    await tester.pump();
    expect(state.checklistDrag.isDragging, isFalse);
    expect(state.checklistDrag.dragged.value, isNull);
    expect(find.byKey(const Key('checklist-drag-ghost')), findsNothing);
  });

  testWidgets('dragging an item below a later line reorders the document', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(2)) + const Offset(0, 5),
    );
    expect(state.checklistDrag.indicatorY, isNotNull);
    expect(find.byKey(const Key('checklist-drag-indicator')), findsOneWidget);
    await gesture.up();
    await tester.pump();

    expect(lines(state), [
      ('b', 'unchecked'),
      ('c', 'unchecked'),
      ('a', 'unchecked'),
      ('d', 'unchecked'),
    ]);
    final aTop = tester.getTopLeft(find.text('a', findRichText: true)).dy;
    final cTop = tester.getTopLeft(find.text('c', findRichText: true)).dy;
    expect(aTop, greaterThan(cTop));
  });

  testWidgets('dragging an item above an earlier line reorders the document', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(3));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(1)) - const Offset(0, 5),
    );
    await gesture.up();
    await tester.pump();

    expect(lines(state), [
      ('a', 'unchecked'),
      ('d', 'unchecked'),
      ('b', 'unchecked'),
      ('c', 'unchecked'),
    ]);
  });

  testWidgets('dropping at the original position changes nothing', (
    tester,
  ) async {
    var changes = 0;
    final (state, _) = await pumpEditor(
      tester,
      content: checklist(abcd),
      onChanged: () => changes++,
    );

    final gesture = await startDrag(tester, checkboxSlot(1));
    expect(state.checklistDrag.indicatorY, isNull);
    expect(find.byKey(const Key('checklist-drag-indicator')), findsNothing);
    await gesture.up();
    await tester.pump();

    expect(lines(state), abcd);
    expect(changes, 0);
  });

  testWidgets('a drag never moves the cursor or opens the keyboard', (
    tester,
  ) async {
    final (state, focusNode) = await pumpEditor(
      tester,
      content: checklist(abcd),
    );
    state.controller.updateSelection(
      const TextSelection.collapsed(offset: 7),
      ChangeSource.local,
    );
    await tester.pump();

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(2)) + const Offset(0, 5),
    );
    await gesture.up();
    await tester.pump();

    expect(lines(state).map((l) => l.$1), ['b', 'c', 'a', 'd']);
    expect(focusNode.hasFocus, isFalse);
    expect(
      state.controller.selection,
      const TextSelection.collapsed(offset: 7),
    );
  });

  testWidgets(
    'with sorting on, items move freely across the checked boundary',
    (tester) async {
      final (state, _) = await pumpEditor(
        tester,
        content: checklist(const [
          ('a', 'unchecked'),
          ('b', 'unchecked'),
          ('c', 'checked'),
          ('d', 'checked'),
        ]),
        sortChecklistItems: true,
      );

      final gesture = await startDrag(tester, checkboxSlot(0));
      await dragTo(
        tester,
        gesture,
        tester.getCenter(checkboxSlot(3)) + const Offset(0, 5),
      );
      await gesture.up();
      await tester.pump();

      expect(lines(state), [
        ('b', 'unchecked'),
        ('c', 'checked'),
        ('d', 'checked'),
        ('a', 'unchecked'),
      ]);
    },
  );

  testWidgets(
    'with sorting on, a checked item reorders within the checked section',
    (tester) async {
      final (state, _) = await pumpEditor(
        tester,
        content: checklist(const [
          ('a', 'unchecked'),
          ('b', 'unchecked'),
          ('c', 'checked'),
          ('d', 'checked'),
        ]),
        sortChecklistItems: true,
      );

      final gesture = await startDrag(tester, checkboxSlot(3));
      await dragTo(
        tester,
        gesture,
        tester.getCenter(checkboxSlot(2)) - const Offset(0, 5),
      );
      await gesture.up();
      await tester.pump();

      expect(lines(state), [
        ('a', 'unchecked'),
        ('b', 'unchecked'),
        ('d', 'checked'),
        ('c', 'checked'),
      ]);
    },
  );

  testWidgets(
    'with sorting on, a mixed (unsorted) group has no section barrier',
    (tester) async {
      final (state, _) = await pumpEditor(
        tester,
        content: checklist(const [
          ('a', 'unchecked'),
          ('b', 'checked'),
          ('c', 'unchecked'),
        ]),
        sortChecklistItems: true,
      );

      final gesture = await startDrag(tester, checkboxSlot(0));
      await dragTo(
        tester,
        gesture,
        tester.getCenter(checkboxSlot(2)) + const Offset(0, 5),
      );
      await gesture.up();
      await tester.pump();

      expect(lines(state), [
        ('b', 'checked'),
        ('c', 'unchecked'),
        ('a', 'unchecked'),
      ]);
    },
  );

  const nestedAbcd = [
    ('a', 'unchecked', 0),
    ('a1', 'unchecked', 1),
    ('a2', 'unchecked', 1),
    ('b', 'unchecked', 0),
  ];

  testWidgets('dragging a parent carries its indented children', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(
      tester,
      content: nestedChecklist(nestedAbcd),
    );

    final gesture = await startDrag(tester, checkboxSlot(0));
    expect(state.checklistDrag.childCount, 2);

    final text = state.controller.document.toPlainText();
    expect(
      state.checklistDrag.dragged.value,
      TextRange(start: 0, end: text.indexOf('b') - 1),
    );

    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(3)) + const Offset(0, 5),
    );
    await gesture.up();
    await tester.pump();

    expect(nestedLines(state), [
      ('b', 'unchecked', 0),
      ('a', 'unchecked', 0),
      ('a1', 'unchecked', 1),
      ('a2', 'unchecked', 1),
    ]);
  });

  testWidgets('a child reorders within its parent keeping its indent', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(
      tester,
      content: nestedChecklist(nestedAbcd),
    );

    final gesture = await startDrag(tester, checkboxSlot(1));
    expect(state.checklistDrag.childCount, 0);
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(2)) + const Offset(0, 5),
    );

    expect(
      state.checklistDrag.indicatorLeft,
      AnchorTokens.space32 + AnchorTokens.sizeListIndent,
    );

    await gesture.up();
    await tester.pump();

    expect(nestedLines(state), [
      ('a', 'unchecked', 0),
      ('a2', 'unchecked', 1),
      ('a1', 'unchecked', 1),
      ('b', 'unchecked', 0),
    ]);
  });

  testWidgets('dragging sideways re-indents the item in place', (tester) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(1));
    expect(state.checklistDrag.indicatorY, isNull);
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(1)) + const Offset(30, 0),
    );

    expect(state.checklistDrag.indicatorY, isNotNull);
    expect(
      state.checklistDrag.indicatorLeft,
      AnchorTokens.space32 + AnchorTokens.sizeListIndent,
    );

    await gesture.up();
    await tester.pump();

    expect(nestedLines(state), [
      ('a', 'unchecked', 0),
      ('b', 'unchecked', 1),
      ('c', 'unchecked', 0),
      ('d', 'unchecked', 0),
    ]);
  });

  testWidgets('a drop can re-indent the block to the hovered gap level', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(
      tester,
      content: nestedChecklist(nestedAbcd),
    );

    final gesture = await startDrag(tester, checkboxSlot(3));
    final start = tester.getCenter(checkboxSlot(3));
    // The seam between a and a1, shifted one indent step to the right.
    final gapY = tester.getTopLeft(checkboxSlot(1)).dy;
    await dragTo(tester, gesture, Offset(start.dx + 30, gapY));
    await gesture.up();
    await tester.pump();

    expect(nestedLines(state), [
      ('a', 'unchecked', 0),
      ('b', 'unchecked', 1),
      ('a1', 'unchecked', 1),
      ('a2', 'unchecked', 1),
    ]);
  });

  testWidgets('a parent whose subtree fills the group does not lift', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(
      tester,
      content: nestedChecklist(const [
        ('p', 'unchecked', 0),
        ('c1', 'unchecked', 1),
        ('c2', 'unchecked', 1),
      ]),
    );

    final gesture = await startDrag(tester, checkboxSlot(0));
    expect(state.checklistDrag.isDragging, isFalse);
    await gesture.up();
    await tester.pump();
    expect(nestedLines(state).map((l) => l.$1), ['p', 'c1', 'c2']);
  });

  testWidgets('an item alone in its group does not lift', (tester) async {
    const loneItem =
        '{"ops":[{"insert":"intro\\n"},{"insert":"a"},'
        '{"insert":"\\n","attributes":{"list":"unchecked"}},'
        '{"insert":"outro\\n"}]}';
    final (state, _) = await pumpEditor(tester, content: loneItem);

    final gesture = await startDrag(tester, checkboxSlot(0));
    expect(state.checklistDrag.isDragging, isFalse);
    await gesture.up();
    await tester.pump();

    expect(state.getContent(), contains('"list":"unchecked"'));
  });

  testWidgets('read-only editors do not lift items', (tester) async {
    final (state, _) = await pumpEditor(
      tester,
      content: checklist(abcd),
      canEdit: false,
    );

    final gesture = await startDrag(tester, checkboxSlot(0));
    expect(state.checklistDrag.isDragging, isFalse);
    await gesture.up();
    await tester.pump();
    expect(lines(state), abcd);
  });

  testWidgets('a drag is one undo entry and undo restores the order', (
    tester,
  ) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(3)) + const Offset(0, 5),
    );
    await gesture.up();
    await tester.pump();
    expect(lines(state).map((l) => l.$1), ['b', 'c', 'd', 'a']);

    state.controller.undo();
    await tester.pump();
    expect(lines(state), abcd);
  });

  testWidgets('checkbox taps still toggle after a drag', (tester) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(2)) + const Offset(0, 5),
    );
    await gesture.up();
    await tester.pump();

    await tester.tap(checkboxSlot(0));
    await tester.pump();
    expect(lines(state).first, ('b', 'checked'));
    // Drain the tap recognizer's double-tap timer.
    await tester.pump(const Duration(milliseconds: 400));
  });

  List<(String, String)> numbered(int count) => [
    for (var i = 0; i < count; i++) ('item $i', 'unchecked'),
  ];

  ScrollController scrollOf(WidgetTester tester) => tester
      .widget<RichTextEditor>(find.byType(RichTextEditor))
      .scrollController;

  testWidgets('near the bottom of what you can see, the note scrolls down', (
    tester,
  ) async {
    await pumpEditor(tester, content: checklist(numbered(60)));
    final scroll = scrollOf(tester);
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;

    final gesture = await startDrag(tester, checkboxSlot(2));
    // 56 above the bottom is the edge; 16 past it scrolls 4 a frame.
    await gesture.moveTo(Offset(40, view.height - 56 + 16));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(scroll.offset, moreOrLessEquals(40, epsilon: 5));

    // Never faster than 14 a frame.
    await gesture.moveTo(Offset(40, view.height + 400));
    await tester.pump();
    final from = scroll.offset;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(scroll.offset - from, moreOrLessEquals(140, epsilon: 15));

    await gesture.moveTo(const Offset(40, 300));
    await tester.pump();
    final still = scroll.offset;
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, still);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('the edges follow the bars and the keyboard', (tester) async {
    const area = Rect.fromLTRB(0, 100, 800, 400);
    await pumpEditor(
      tester,
      content: checklist(numbered(60)),
      visibleArea: area,
    );
    final scroll = scrollOf(tester);
    scroll.jumpTo(200);
    await tester.pump();

    final gesture = await startDrag(tester, checkboxSlot(15));
    await gesture.moveTo(const Offset(40, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, 200);

    // 40 under the area's top is the edge.
    await gesture.moveTo(const Offset(40, 100 + 40 - 20));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(scroll.offset, moreOrLessEquals(200 - 50, epsilon: 6));

    await gesture.moveTo(const Offset(40, 400 - 56 + 20));
    await tester.pump();
    final from = scroll.offset;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(scroll.offset - from, moreOrLessEquals(50, epsilon: 6));
    await gesture.up();
    await tester.pump();
  });

  testWidgets('folded items are no place to drop: the item lands above the '
      'row', (tester) async {
    final (state, _) = await pumpEditor(
      tester,
      content: checklist(const [
        ('a', 'unchecked'),
        ('b', 'unchecked'),
        ('c', 'checked'),
        ('d', 'checked'),
      ]),
      sortChecklistItems: true,
      isCheckedFolded: true,
    );

    final gesture = await startDrag(tester, checkboxSlot(0));
    final row = tester.getRect(find.byType(CheckedFoldRow));
    await dragTo(tester, gesture, Offset(40, row.bottom + 30));
    expect(
      state.checklistDrag.indicatorY,
      moreOrLessEquals(
        tester.getTopLeft(find.byType(CheckedFoldRow)).dy -
            tester.getTopLeft(find.byType(RichTextEditor)).dy,
        epsilon: 0.5,
      ),
    );
    await gesture.up();
    await tester.pump();

    expect(lines(state), [
      ('b', 'unchecked'),
      ('a', 'unchecked'),
      ('c', 'checked'),
      ('d', 'checked'),
    ]);
  });

  testWidgets('the ghost is a small chip up and left of the finger, kept off '
      'the sides', (tester) async {
    await pumpEditor(
      tester,
      content: nestedChecklist(const [
        ('a', 'unchecked', 0),
        (
          'a long item that does not fit in the small chip at all',
          'checked',
          0,
        ),
        ('child', 'unchecked', 1),
        ('b', 'unchecked', 0),
      ]),
    );
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;

    final gesture = await startDrag(tester, checkboxSlot(1));
    final ghost = find.byKey(const Key('checklist-drag-ghost'));
    expect(find.text('+1'), findsOneWidget);
    expect(tester.getSize(ghost).height, AnchorTokens.sizeControlSmall);
    expect(tester.getSize(ghost).width, 240);
    final text = tester.widget<Text>(
      find.descendant(of: ghost, matching: find.textContaining('a long')),
    );
    expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
    expect(text.style?.fontSize, 14);

    await gesture.moveTo(const Offset(4, 300));
    await tester.pump();
    expect(tester.getTopLeft(ghost), const Offset(8, 300 - 56));

    await gesture.moveTo(Offset(view.width - 4, 300));
    await tester.pump();
    expect(tester.getTopRight(ghost).dx, view.width - 8);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('the drop line starts at the text of the new indent and ends at '
      'the edge', (tester) async {
    await pumpEditor(tester, content: checklist(abcd));
    final editor = tester.getRect(find.byType(RichTextEditor));

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(2)) + const Offset(30, 5),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final line = tester.getRect(
      find.byKey(const Key('checklist-drag-indicator')),
    );
    expect(
      line.left + 4,
      editor.left + AnchorTokens.space32 + AnchorTokens.sizeListIndent,
    );
    expect(line.right, editor.right);
    expect(line.height, 8);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('Escape puts a dragged item back', (tester) async {
    final (state, _) = await pumpEditor(tester, content: checklist(abcd));

    final gesture = await startDrag(tester, checkboxSlot(0));
    await dragTo(
      tester,
      gesture,
      tester.getCenter(checkboxSlot(3)) + const Offset(0, 5),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(state.checklistDrag.isDragging, isFalse);
    await gesture.up();
    await tester.pump();

    expect(lines(state), abcd);
  });

  testWidgets('the box is named by its item and says how to drag it', (
    tester,
  ) async {
    await pumpEditor(tester, content: checklist(abcd));
    final box = tester.getSemantics(checkboxSlot(1));
    expect(box.label, 'b');
    expect(box.hint, 'Drag to reorder');
  });
}
