import 'package:anchor/core/logging/app_logger.dart';
import 'package:anchor/features/settings/presentation/log_viewer_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final logger = AppLogger.instance;
  late LogViewerController logs;

  setUp(() async {
    await logger.clear();
    logger.info('Test', 'first');
    logs = LogViewerController();
  });

  tearDown(() async {
    logs.dispose();
    await logger.clear();
  });

  List<String> messages() => [for (final entry in logs.shown) entry.message];

  test('starts with what was logged and adds new lines as they come', () async {
    var linesAdded = 0;
    logs.dispose();
    logs = LogViewerController(onLineAdded: () => linesAdded++);
    logger.warn('Test', 'second');
    await pumpEventQueue();

    expect(messages().skip(1), ['first', 'second']);
    expect(linesAdded, 1);
  });

  test('filters by level and words', () async {
    logger.warn('Sync', 'paused');
    logger.error('Sync', 'failed');
    await pumpEventQueue();

    logs.showLevel(LogLevel.warn);
    expect(messages(), ['paused']);

    logs.showLevel(null);
    logs.search('FAIL');
    expect(messages(), ['failed']);
  });

  test('copies the selected lines that are shown, in order', () async {
    logger.info('Test', 'second');
    await pumpEventQueue();
    final [_, first, second] = logs.shown;

    logs.startSelecting(second);
    logs.toggle(first);
    expect(logs.selectedLines(), [first.format(), second.format()]);

    logs.search('second');
    expect(logs.selectedLines(), [second.format()]);
  });

  test('keeps as many lines as the logger does', () async {
    final oldest = logs.shown.first;
    logs.startSelecting(oldest);
    for (var i = 0; i < AppLogger.bufferCapacity; i++) {
      logger.debug('Test', 'line $i');
    }
    await pumpEventQueue();

    expect(logs.shown, hasLength(AppLogger.bufferCapacity));
    expect(logs.shown.first.message, 'line 0');
    expect(logs.isSelected(oldest), isFalse);
    expect(logs.selectedCount, 0);
  });

  test('clearing leaves only the line that says so', () async {
    await logs.clear();
    await pumpEventQueue();

    expect(messages(), ['Logs cleared']);
  });
}
