import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anchor/core/network/sync_requester.dart';
import 'package:anchor/features/sync/data/sync_api.dart';
import 'package:anchor/features/sync/data/sync_events.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(Options());
  });

  late MockDio dio;
  late List<Completer<Response<ResponseBody>>> answers;
  late int syncs;

  setUp(() {
    dio = MockDio();
    answers = [];
    syncs = 0;
    when(
      () => dio.get<ResponseBody>(
        any(),
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) {
      final answer = Completer<Response<ResponseBody>>();
      answers.add(answer);
      return answer.future;
    });
    registerAppSyncRequester(() async => syncs++);
    addTearDown(() => registerAppSyncRequester(null));
  });

  Response<ResponseBody> opened(Stream<Uint8List> body) => Response(
    requestOptions: RequestOptions(path: syncEventsPath),
    statusCode: 200,
    data: ResponseBody(body, 200),
  );

  Uint8List syncMessage() => utf8.encode('event: sync\n\n');

  test('a sync message starts a sync', () async {
    final events = SyncEvents(dio);
    addTearDown(events.disconnect);
    final channel = StreamController<Uint8List>();

    events.connect();
    await pumpEventQueue();
    answers.single.complete(opened(channel.stream));
    await pumpEventQueue();
    channel.add(syncMessage());
    await pumpEventQueue();

    expect(syncs, 1);
  });

  test('an answer that arrives after reconnecting is dropped', () async {
    final events = SyncEvents(dio);
    addTearDown(events.disconnect);
    final stale = StreamController<Uint8List>();
    final live = StreamController<Uint8List>();

    events.connect();
    await pumpEventQueue();
    events.disconnect();
    events.connect();
    await pumpEventQueue();
    expect(answers, hasLength(2));

    answers.first.complete(opened(stale.stream));
    answers.last.complete(opened(live.stream));
    await pumpEventQueue();

    stale.add(syncMessage());
    await pumpEventQueue();
    expect(syncs, 0, reason: 'the old answer must not be listened to');

    live.add(syncMessage());
    await pumpEventQueue();
    expect(syncs, 1);
  });

  test('an answer that arrives after disconnecting is dropped', () async {
    final events = SyncEvents(dio);
    final stale = StreamController<Uint8List>();

    events.connect();
    await pumpEventQueue();
    events.disconnect();
    answers.single.complete(opened(stale.stream));
    await pumpEventQueue();

    stale.add(syncMessage());
    await pumpEventQueue();
    expect(syncs, 0);
  });
}
