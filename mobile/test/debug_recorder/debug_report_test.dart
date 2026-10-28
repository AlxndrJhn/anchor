import 'package:anchor/features/debug_recorder/data/debug_report.dart';
import 'package:anchor/features/debug_recorder/data/debug_state_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime.utc(2026, 10, 28, 14, 3, 22, 456);

  test('names the file by its ISO start time', () {
    expect(isoSecond(startedAt), '2026-10-28T14:03:22Z');
    expect(
      debugReportFilename(startedAt),
      'anchor-debug-2026-10-28T14-03-22Z.mp4',
    );
  });

  test('writes video times as mm:ss.s', () {
    expect(formatVideoTime(0), '00:00.0');
    expect(formatVideoTime(3240), '00:03.2');
    expect(formatVideoTime(14960), '00:15.0');
    expect(formatVideoTime(61500), '01:01.5');
  });

  test('fills in a new issue with the problems', () {
    final url = debugIssueUrl(
      repo: 'AlxndrJhn/anchor',
      startedAt: startedAt,
      problems: const [
        DebugProblem(7100, 'Saved'),
        DebugProblem(3240, 'The list\nscrolls'),
      ],
      filename: 'anchor-debug-2026-10-28T14-03-22Z.mp4',
      appVersion: '0.17.2+22',
    );
    expect(url.host, 'github.com');
    expect(url.path, '/AlxndrJhn/anchor/issues/new');
    expect(url.queryParameters['title'], 'Debug report 2026-10-28T14:03:22Z');
    final body = url.queryParameters['body']!;
    expect(
      body,
      contains(
        '- [00:03.2] Expectation: The list scrolls\n'
        '- [00:07.1] Expectation: Saved',
      ),
    );
    expect(body, contains('App version: 0.17.2+22'));
    expect(body, contains('`anchor-debug-2026-10-28T14-03-22Z.mp4`'));
  });

  group('describeStateValue', () {
    test('hides credentials', () {
      expect(
        describeStateValue('User(id: 1, email: a@b.c, accessToken: xyz)'),
        'User(id: 1, email: ***, accessToken: ***)',
      );
      expect(
        describeStateValue({'id': 'n', 'password': 'p'}),
        '{id: n, password: ***}',
      );
    });

    test('sums up lists and unwraps async values', () {
      expect(
        describeStateValue(const AsyncData([1, 2, 3])),
        'List<int>(length: 3, first: 1)',
      );
      expect(describeStateValue(const AsyncLoading<int>()), 'AsyncLoading()');
    });

    test('cuts long values short', () {
      expect(describeStateValue('x' * 1000).length, 301);
    });
  });
}
