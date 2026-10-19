import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';

class LogViewerController extends ChangeNotifier {
  LogViewerController({AppLogger? logger, this.onLineAdded})
    : _logger = logger ?? AppLogger.instance {
    _entries.addAll(_logger.snapshot);
    _subscription = _logger.stream.listen(_add);
  }

  final AppLogger _logger;
  late final StreamSubscription<LogEntry> _subscription;
  final List<LogEntry> _entries = [];
  final Set<LogEntry> _expanded = {};
  final Set<LogEntry> _selected = {};
  LogLevel? _level;
  String _query = '';
  bool _isSearching = false;
  bool _isSelecting = false;

  /// Runs as a new line comes in, before listeners hear of it.
  final VoidCallback? onLineAdded;

  bool get hasEntries => _entries.isNotEmpty;

  List<LogEntry> get shown {
    final words = _query.trim().toLowerCase();
    return [
      for (final entry in _entries)
        if ((_level == null || entry.level == _level) &&
            (words.isEmpty ||
                '${entry.tag} ${entry.message}'.toLowerCase().contains(words)))
          entry,
    ];
  }

  LogLevel? get level => _level;
  String get query => _query;
  bool get isSearching => _isSearching;
  bool get isSelecting => _isSelecting;
  int get selectedCount => _selected.length;

  bool isExpanded(LogEntry entry) => _expanded.contains(entry);
  bool isSelected(LogEntry entry) => _selected.contains(entry);

  bool get isAllShownSelected {
    final lines = shown;
    return lines.isNotEmpty && lines.every(_selected.contains);
  }

  void _add(LogEntry entry) {
    _entries.add(entry);
    final excess = _entries.length - AppLogger.bufferCapacity;
    if (excess > 0) {
      final dropped = _entries.sublist(0, excess);
      _entries.removeRange(0, excess);
      _expanded.removeAll(dropped);
      _selected.removeAll(dropped);
    }
    onLineAdded?.call();
    notifyListeners();
  }

  void showLevel(LogLevel? level) {
    _level = level;
    notifyListeners();
  }

  void startSearch() {
    _isSearching = true;
    notifyListeners();
  }

  void search(String query) {
    _query = query;
    notifyListeners();
  }

  void stopSearch() {
    _isSearching = false;
    _query = '';
    notifyListeners();
  }

  void startSelecting([LogEntry? first]) {
    _isSelecting = true;
    if (first != null) _selected.add(first);
    notifyListeners();
  }

  void stopSelecting() {
    _isSelecting = false;
    _selected.clear();
    notifyListeners();
  }

  /// Toggles selection while selecting, otherwise expansion.
  void toggle(LogEntry entry) {
    final lines = _isSelecting ? _selected : _expanded;
    if (!lines.remove(entry)) lines.add(entry);
    notifyListeners();
  }

  void toggleAllShown() {
    if (isAllShownSelected) {
      _selected.clear();
    } else {
      _selected.addAll(shown);
    }
    notifyListeners();
  }

  List<String> selectedLines() => [
    for (final entry in shown)
      if (_selected.contains(entry)) entry.format(),
  ];

  /// Deletes every saved log, this session's and earlier ones.
  Future<void> clear() async {
    // The line saying they were cleared comes in through the stream.
    _entries.clear();
    _expanded.clear();
    _selected.clear();
    notifyListeners();
    await _logger.clear();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
