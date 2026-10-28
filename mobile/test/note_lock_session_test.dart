import 'package:anchor/features/note_locks/presentation/note_lock_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('relock locks that note again and leaves the others open', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(noteLockSessionProvider.notifier);

    session
      ..unlock('a')
      ..unlock('b')
      ..relock('a');

    expect(container.read(noteLockSessionProvider), {'b'});
  });

  test('relock of a note not opened changes nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(noteLockSessionProvider.notifier)
      ..unlock('a');
    final before = container.read(noteLockSessionProvider);

    session.relock('b');

    expect(identical(container.read(noteLockSessionProvider), before), true);
  });
}
