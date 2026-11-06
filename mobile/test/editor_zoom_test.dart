import 'package:anchor/features/notes/presentation/editor/list_markers.dart';
import 'package:anchor/features/notes/presentation/editor/note_zoom.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checklist_drag_test.dart' show checklist, palette;

void main() {
  testWidgets('a pinched checklist has bigger checkboxes that still check', (
    tester,
  ) async {
    final zoom = ValueNotifier<double>(1);
    final isPinching = ValueNotifier(false);
    final scroll = ScrollController();
    final focus = FocusNode();
    final box = GlobalKey();
    addTearDown(() {
      zoom.dispose();
      isPinching.dispose();
      scroll.dispose();
      focus.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        home: Scaffold(
          body: PinchZoom(
            zoom: zoom,
            box: box,
            scroll: scroll,
            isPinching: isPinching,
            onZoomEnd: (_) {},
            child: ValueListenableBuilder(
              valueListenable: isPinching,
              builder: (context, pinching, _) => CustomScrollView(
                controller: scroll,
                physics: pinching
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ValueListenableBuilder(
                      valueListenable: zoom,
                      builder: (context, value, editor) =>
                          ZoomedBox(key: box, zoom: value, child: editor),
                      child: RichTextEditor(
                        initialContent: checklist([
                          ('Milk', 'unchecked'),
                          ('Eggs', 'unchecked'),
                          ('Bread', 'unchecked'),
                        ]),
                        focusNode: focus,
                        sortChecklistItems: false,
                        scrollController: scroll,
                        palette: palette,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Rect checkbox(int index) =>
        tester.getRect(find.byType(NoteCheckBox).at(index));
    final small = checkbox(1);

    final first = await tester.startGesture(const Offset(200, 20));
    final second = await tester.startGesture(const Offset(200, 60));
    await first.moveTo(const Offset(200, 0));
    await second.moveTo(const Offset(200, 80));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(zoom.value, closeTo(2, 0.001));
    final big = checkbox(1);
    expect(big.width, closeTo(small.width * 2, 0.01));

    await tester.tapAt(big.center);
    await tester.pumpAndSettle();
    final state = tester.state<RichTextEditorState>(
      find.byType(RichTextEditor),
    );
    final lists = [
      for (final op in state.controller.document.toDelta().toList())
        if (op.attributes?['list'] case final String list) list,
    ];
    expect(lists, ['unchecked', 'checked', 'unchecked']);
  });
}
