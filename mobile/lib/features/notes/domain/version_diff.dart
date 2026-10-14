import 'dart:math' as math;
import 'dart:typed_data';

import 'note_blocks.dart';

// Must match the web's version-diff.ts.

enum WordKind { same, removed, added }

class WordPart {
  WordPart(this.text, this.kind);

  String text;
  final WordKind kind;
}

enum ChangeKind { same, removed, added, changed }

class VersionLine {
  const VersionLine(this.kind, this.block, {this.words = const []});

  final ChangeKind kind;
  final NoteBlock block;

  /// Empty unless the line changed.
  final List<WordPart> words;
}

class VersionDiff {
  const VersionDiff(this.lines);

  final List<VersionLine> lines;

  int get added => lines.where((l) => l.kind == ChangeKind.added).length;
  int get removed => lines.where((l) => l.kind == ChangeKind.removed).length;
  int get changed => lines.where((l) => l.kind == ChangeKind.changed).length;
  bool get isUnchanged => added == 0 && removed == 0 && changed == 0;
}

/// Lines [from] up to, not including, [to].
class FoldedLines {
  const FoldedLines(this.from, this.to);

  final int from;
  final int to;
}

const _maxCells = 1000000;

/// How alike two lines must be to count as one line that changed.
const _minSimilarity = 0.4;

String _keyOf(NoteBlock block) => [
  block.type.name,
  block.level,
  block.done ? 1 : 0,
  block.text,
].join('\u0000');

int Function(int, int) _longestCommonSubsequence<T>(List<T> a, List<T> b) {
  final width = b.length + 1;
  final table = Uint32List((a.length + 1) * width);
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      table[i * width + j] = a[i] == b[j]
          ? table[(i + 1) * width + j + 1] + 1
          : math.max(table[(i + 1) * width + j], table[i * width + j + 1]);
    }
  }
  return (i, j) => table[i * width + j];
}

List<WordPart> diffWords(String before, String after) {
  final splitter = RegExp(r'(\s+)');
  List<String> words(String text) {
    final out = <String>[];
    var at = 0;
    for (final match in splitter.allMatches(text)) {
      if (match.start > at) out.add(text.substring(at, match.start));
      out.add(match.group(0)!);
      at = match.end;
    }
    if (at < text.length) out.add(text.substring(at));
    return out;
  }

  final oldWords = words(before);
  final newWords = words(after);
  final parts = <WordPart>[];
  void push(String text, WordKind kind) {
    if (parts.isNotEmpty && parts.last.kind == kind) {
      parts.last.text += text;
    } else {
      parts.add(WordPart(text, kind));
    }
  }

  if ((oldWords.length + 1) * (newWords.length + 1) > _maxCells) {
    push(before, WordKind.removed);
    push(after, WordKind.added);
    return parts;
  }
  final common = _longestCommonSubsequence(oldWords, newWords);
  var i = 0;
  var j = 0;
  while (i < oldWords.length && j < newWords.length) {
    if (oldWords[i] == newWords[j]) {
      push(oldWords[i++], WordKind.same);
      j++;
    } else if (common(i + 1, j) >= common(i, j + 1)) {
      push(oldWords[i++], WordKind.removed);
    } else {
      push(newWords[j++], WordKind.added);
    }
  }
  while (i < oldWords.length) {
    push(oldWords[i++], WordKind.removed);
  }
  while (j < newWords.length) {
    push(newWords[j++], WordKind.added);
  }
  return parts;
}

double _similarity(String a, String b) {
  final wordsA = a
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final wordsB = b
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (wordsA.isEmpty || wordsB.isEmpty) return 0;
  return 2 *
      _longestCommonSubsequence(wordsA, wordsB)(0, 0) /
      (wordsA.length + wordsB.length);
}

/// What changed from [before] (a version) to [after] (the one that came
/// next): lines added, removed, or changed with their words marked.
VersionDiff diffVersions(String? before, String? after) {
  final oldBlocks = parseNoteBlocks(before).where((b) => !b.isEmpty).toList();
  final newBlocks = parseNoteBlocks(after).where((b) => !b.isEmpty).toList();
  final oldKeys = oldBlocks.map(_keyOf).toList();
  final newKeys = newBlocks.map(_keyOf).toList();

  final raw = <VersionLine>[];
  if ((oldBlocks.length + 1) * (newBlocks.length + 1) > _maxCells) {
    raw
      ..addAll(oldBlocks.map((b) => VersionLine(ChangeKind.removed, b)))
      ..addAll(newBlocks.map((b) => VersionLine(ChangeKind.added, b)));
  } else {
    final common = _longestCommonSubsequence(oldKeys, newKeys);
    var i = 0;
    var j = 0;
    while (i < oldBlocks.length && j < newBlocks.length) {
      if (oldKeys[i] == newKeys[j]) {
        raw.add(VersionLine(ChangeKind.same, oldBlocks[i++]));
        j++;
      } else if (common(i + 1, j) >= common(i, j + 1)) {
        raw.add(VersionLine(ChangeKind.removed, oldBlocks[i++]));
      } else {
        raw.add(VersionLine(ChangeKind.added, newBlocks[j++]));
      }
    }
    while (i < oldBlocks.length) {
      raw.add(VersionLine(ChangeKind.removed, oldBlocks[i++]));
    }
    while (j < newBlocks.length) {
      raw.add(VersionLine(ChangeKind.added, newBlocks[j++]));
    }
  }

  // In each run of changes, a removed line much like an added one is one
  // line that changed.
  final lines = <VersionLine>[];
  for (var start = 0; start < raw.length;) {
    if (raw[start].kind == ChangeKind.same) {
      lines.add(raw[start++]);
      continue;
    }
    var end = start;
    while (end < raw.length && raw[end].kind != ChangeKind.same) {
      end++;
    }
    final run = raw.sublist(start, end);
    final added = run.where((l) => l.kind == ChangeKind.added).toList();
    final used = <int>{};
    final out = <VersionLine?>[
      for (final line in run)
        if (line.kind != ChangeKind.removed)
          line
        else
          () {
            final match = [
              for (var k = 0; k < added.length; k++)
                if (!used.contains(k) &&
                    (added[k].block.text == line.block.text ||
                        _similarity(line.block.text, added[k].block.text) >=
                            _minSimilarity))
                  k,
            ].firstOrNull;
            if (match == null) return line;
            used.add(match);
            return VersionLine(
              ChangeKind.changed,
              line.block,
              words: diffWords(line.block.text, added[match].block.text),
            );
          }(),
    ];
    for (var k = 0; k < run.length; k++) {
      if (run[k].kind == ChangeKind.added &&
          used.contains(added.indexOf(run[k]))) {
        out[k] = null;
      }
    }
    lines.addAll(out.whereType<VersionLine>());
    start = end;
  }
  return VersionDiff(lines);
}

/// Line indexes to show, with three or more unchanged lines away from any
/// change folded into one. [open] holds lines already opened.
List<Object> foldLines(List<VersionLine> lines, [Set<int> open = const {}]) {
  final keep = [
    for (var k = 0; k < lines.length; k++)
      open.contains(k) ||
          [k - 2, k - 1, k, k + 1, k + 2].any(
            (j) =>
                j >= 0 && j < lines.length && lines[j].kind != ChangeKind.same,
          ),
  ];
  final out = <Object>[];
  for (var k = 0; k < lines.length;) {
    if (!keep[k]) {
      var end = k;
      while (end < lines.length && !keep[end]) {
        end++;
      }
      if (end - k > 2) {
        out.add(FoldedLines(k, end));
        k = end;
        continue;
      }
    }
    out.add(k++);
  }
  return out;
}
