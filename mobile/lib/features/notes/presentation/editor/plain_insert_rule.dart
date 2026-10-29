import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart';
// ignore: experimental_member_use
import 'package:flutter_quill/internal.dart'
    show
        AutoExitBlockRule,
        CatchAllInsertRule,
        InsertRule,
        PreserveBlockStyleOnInsertRule,
        PreserveInlineStylesRule,
        PreserveLineStyleOnSplitRule,
        ResetLineFormatOnNewLineRule;

/// Quill's insert rules for text without the two that link http addresses
/// letter by letter. Custom rules are shared by every document and run first.
class PlainInsertRule extends InsertRule {
  const PlainInsertRule();

  static const List<InsertRule> _rules = [
    AutoExitBlockRule(),
    PreserveBlockStyleOnInsertRule(),
    PreserveLineStyleOnSplitRule(),
    ResetLineFormatOnNewLineRule(),
    PreserveInlineStylesRule(),
    CatchAllInsertRule(),
  ];

  @override
  Delta? applyRule(
    Document document,
    int index, {
    int? len,
    Object? data,
    Attribute? attribute,
  }) {
    if (data is! String) return null;
    for (final rule in _rules) {
      final change = rule.apply(document, index, len: len, data: data);
      if (change != null) return change;
    }
    return null;
  }
}
