import 'dart:async';
import 'dart:io';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAttachmentsRepository extends Mock
    implements NoteAttachmentsRepository {}

void main() {
  late MockAttachmentsRepository repo;
  late StreamController<List<ConnectivityResult>> connectivity;
  late ProviderContainer container;
  late Directory folder;

  const key = (
    noteId: 'n1',
    attachmentId: 'a1',
    filename: 'photo.jpg',
    localPath: null,
  );

  setUp(() {
    repo = MockAttachmentsRepository();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    folder = Directory.systemTemp.createTempSync('attachment_file_test');
    container = ProviderContainer(
      overrides: [
        noteAttachmentsRepositoryProvider.overrideWithValue(repo),
        connectivityStreamProvider.overrideWith((ref) => connectivity.stream),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await connectivity.close();
    folder.deleteSync(recursive: true);
  });

  Future<void> goOnline(bool isOnline) async {
    connectivity.add([
      isOnline ? ConnectivityResult.wifi : ConnectivityResult.none,
    ]);
    await Future<void>.delayed(Duration.zero);
  }

  test('the copy on the phone is there at once', () {
    final file = File('${folder.path}/photo.jpg')..writeAsBytesSync([1, 2, 3]);
    final local = (
      noteId: 'n1',
      attachmentId: 'a1',
      filename: 'photo.jpg',
      localPath: file.path,
    );

    final loaded = container.read(attachmentFileProvider(local));

    expect(loaded, AsyncData<String?>(file.path));
    verifyNever(() => repo.downloadAttachment(any(), any(), any()));
  });

  test('offline it waits, then fetches once back online', () async {
    when(
      () => repo.downloadAttachment('n1', 'a1', 'photo.jpg'),
    ).thenAnswer((_) async => '/cache/a1-photo.jpg');
    final online = container.listen(isOnlineProvider, (_, _) {});
    await goOnline(false);
    final listener = container.listen(attachmentFileProvider(key), (_, _) {});

    expect(await container.read(attachmentFileProvider(key).future), isNull);
    verifyNever(() => repo.downloadAttachment(any(), any(), any()));

    await goOnline(true);

    expect(
      await container.read(attachmentFileProvider(key).future),
      '/cache/a1-photo.jpg',
    );
    listener.close();
    online.close();
  });

  test('a download that fails waits to be asked again', () async {
    var calls = 0;
    when(() => repo.downloadAttachment('n1', 'a1', 'photo.jpg')).thenAnswer((
      _,
    ) async {
      calls++;
      throw const SocketException('no route');
    });
    final listener = container.listen(attachmentFileProvider(key), (_, _) {});

    await expectLater(
      container.read(attachmentFileProvider(key).future),
      throwsA(isA<SocketException>()),
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(calls, 1);

    container.invalidate(attachmentFileProvider(key));
    await expectLater(
      container.read(attachmentFileProvider(key).future),
      throwsA(isA<SocketException>()),
    );
    expect(calls, 2);
    listener.close();
  });
}
