import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The labels of the screen reader actions on [finder]'s semantics node,
/// besides the standard ones.
List<String> customActionsOf(WidgetTester tester, Finder finder) => [
  for (final id
      in tester
              .getSemantics(finder)
              .getSemanticsData()
              .customSemanticsActionIds ??
          const <int>[])
    CustomSemanticsAction.getAction(id)!.label!,
];

/// Runs the screen reader action named [label] on [finder]'s node, as
/// TalkBack's actions menu or VoiceOver's rotor does.
void performCustomAction(WidgetTester tester, Finder finder, String label) {
  final node = tester.getSemantics(finder);
  final id = CustomSemanticsAction.getIdentifier(
    CustomSemanticsAction(label: label),
  );
  expect(
    node.getSemanticsData().customSemanticsActionIds,
    contains(id),
    reason: 'no "$label" action',
  );
  node.owner!.performAction(node.id, SemanticsAction.customAction, id);
}

/// Every tap target meets the platform's size, and is labelled, and text is
/// readable against what's behind it.
Future<void> expectAccessibleScreen(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
