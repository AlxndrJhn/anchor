import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Sizes under `lib/` come from the layout scale (4, 8, 12, 16, 24, 32, 48)
/// or named tokens. A line that must keep another number says why after
/// `// off-scale:`, on that line or the one after it.
void main() {
  test('sizes come from the layout scale', () {
    final problems = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.g.dart') &&
              !file.path.contains('/tokens/'),
        );
    for (final file in files) {
      final source = _Source(file.path, file.readAsStringSync());
      for (final (name, pattern) in _rules) {
        for (final match in pattern.allMatches(source.text)) {
          source.check(name, match.start, match.end, problems);
        }
      }
      for (final (start, end) in _positionedEdges(source.text)) {
        source.check('position', start, end, problems);
      }
      for (final (start, end) in _sumsAndChoices(source.text)) {
        source.check(
          'size in a sum or choice',
          start,
          end,
          problems,
          // Factors like `* 0.84` and hairlines under 4 aren't sizes.
          code: source.text
              .substring(start, end)
              .replaceAll(_factor, '')
              .replaceAll(_hairline, ''),
        );
      }
    }
    expect(problems, isEmpty, reason: '\n${problems.join('\n')}');
  });

  // A line that keeps a Default size in Compact says so with
  // `// same in Compact:`, on that line or next to it.
  test('control heights and the bar follow the density', () {
    final problems = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.contains('/tokens/') &&
              !file.path.endsWith('/anchor_density.dart'),
        );
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_fixedDensity.hasMatch(lines[i])) continue;
        final isKept = lines
            .sublist(math.max(0, i - 1), math.min(lines.length, i + 2))
            .any((line) => line.contains('// same in Compact:'));
        if (!isKept) problems.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(problems, isEmpty, reason: '\n${problems.join('\n')}');
  });
}

final _fixedDensity = RegExp(
  r'AnchorTokens\.(?:sizeControlLarge|sizeButtonPhone|sizeDock|sizeRow|sizeFieldPhone|density\w+)\b|PageBar\.height\b',
);

class _Source {
  _Source(this.path, this.text)
    : lines = text.split('\n'),
      drawings = [
        for (final m in RegExp(
          r'class \w+ extends CustomPainter',
        ).allMatches(text))
          (
            m.start,
            text.indexOf('\nclass ', m.end) == -1
                ? text.length
                : text.indexOf('\nclass ', m.end),
          ),
      ];

  final String path;
  final String text;
  final List<String> lines;
  final List<(int, int)> drawings;

  void check(
    String rule,
    int start,
    int end,
    List<String> problems, {
    String? code,
  }) {
    if (drawings.any((d) => start > d.$1 && start < d.$2)) return;
    final lineStart = text.lastIndexOf('\n', start) + 1;
    if (text.substring(lineStart, start).contains('//')) return;
    final line = _lineOf(start);
    final isSpacing = _spacingRules.contains(rule);
    final hasNumber =
        rule.startsWith('token') ||
        _number
            .allMatches(code ?? text.substring(start, end))
            .any(
              (match) =>
                  !_scale.contains(double.parse(match.group(0)!)) ||
                  !isSpacing && !_zero(match),
            );
    final allowed = lines
        .sublist(line, math.min(lines.length, _lineOf(end) + 2))
        .any((l) => l.contains('// off-scale:'));
    if (hasNumber && !allowed) {
      problems.add('$path:${line + 1}: $rule: ${lines[line].trim()}');
    }
  }

  int _lineOf(int offset) => '\n'.allMatches(text.substring(0, offset)).length;
}

bool _zero(Match match) => double.parse(match.group(0)!) == 0;

final _scale = {0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0};

/// Rules whose numbers may be any step of the scale; the others take tokens.
const _spacingRules = {
  'padding',
  'spacing',
  'size or gap',
  'default size',
  'position',
  'size in a sum or choice',
};

/// A number in place: digits not part of a name, a member or a hex color.
final _number = RegExp(r'(?<![\w.$])\d+(?:\.\d+)?(?![\w.])');

final _rules = <(String, RegExp)>[
  ('padding', RegExp(r'EdgeInsets(?:Directional)?\.\w+\([^()]*\)')),
  ('text size', RegExp(r'(?:fontSize:|withSize\()\s*[\d.]+')),
  ('icon size', RegExp(r'\bsize:\s*[\d.]+')),
  ('corner', RegExp(r'Radius\.circular\(\s*[\d.]+')),
  (
    'spacing',
    RegExp(
      r'\b(?:spacing|runSpacing|mainAxisSpacing|crossAxisSpacing):\s*[\d.]+',
    ),
  ),
  // Sizes of 4 and up; smaller ones are hairlines and line heights.
  (
    'size or gap',
    RegExp(
      r'\b(?:height|width|dimension|minHeight|minWidth|maxHeight|maxWidth):\s*(?:[4-9]|\d{2,})(?:\.\d+)?\b',
    ),
  ),
  // A size of 4 and up that a widget falls back to, like `this.size = 34`,
  // or a field starts with, like `double _height = 43`.
  (
    'default size',
    RegExp(
      r'\b(?:this\.|double\s+)_?[a-z]\w*?(?:[Ss]ize|[Hh]eight|[Ww]idth|[Pp]adding|[Gg]ap|[Ss]pacing|[Ii]nset)\s*=\s*(?:[4-9]|\d{2,})(?:\.\d+)?\b',
    ),
  ),
  (
    'token off the scale',
    RegExp(
      r'AnchorTokens\.(?:space(?:2|6|10|14|20|28|40|56|64|80|96|Lg)|radius(?:Xs|Sm|Md|Xl|3xl|Button|Field|MenuItem|Menu|Dialog))\b',
    ),
  ),
];

Iterable<(int, int)> _positionedEdges(String text) sync* {
  for (final call in RegExp(
    r'\b(?:Animated)?Positioned(?:\.\w+)?\(',
  ).allMatches(text)) {
    var depth = 0;
    var argStart = call.end;
    for (var i = call.end - 1; i < text.length; i++) {
      final char = text[i];
      if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']' || char == '}') {
        depth--;
      }
      final argEnds = depth == 1 && char == ',' || depth == 0;
      if (argEnds) {
        final arg = text.substring(argStart, i);
        final edge = RegExp(
          r'^\s*(?:left|top|right|bottom|start|end):',
        ).firstMatch(arg);
        if (edge != null) yield (argStart + edge.end, i);
        argStart = i + 1;
      }
      if (depth == 0) break;
    }
  }
}

/// Where a size is set with a sum or a choice holding a number, like
/// `height: lineHeight + 6` or `width: cupertino ? 36 : 32`.
Iterable<(int, int)> _sumsAndChoices(String text) sync* {
  for (final key in RegExp(
    r'\b(?:height|width|dimension|minHeight|minWidth|maxHeight|maxWidth|size):\s*',
  ).allMatches(text)) {
    final end = _valueEnd(text, key.end);
    final value = text.substring(key.end, end);
    final isSumOrChoice =
        value.contains('?') ||
        RegExp(r'[-+*/]\s*\d|\d\s*[-+*/]').hasMatch(value);
    if (isSumOrChoice && _number.hasMatch(value)) yield (key.end, end);
  }
}

int _valueEnd(String text, int start) {
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) return i;
      depth--;
    } else if ((char == ',' || char == ';') && depth == 0) {
      return i;
    }
  }
  return text.length;
}

final _factor = RegExp(r'[*/]\s*\d+(?:\.\d+)?|\d+(?:\.\d+)?\s*[*/]');
final _hairline = RegExp(r'(?<![\w.$])[0-3](?:\.\d+)?(?![\w.])');
