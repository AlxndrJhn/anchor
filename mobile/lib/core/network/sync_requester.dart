import '../logging/app_logger.dart';
import '../logging/log_tags.dart';

typedef AppSyncRequester = Future<void> Function();

AppSyncRequester? _appSyncRequester;

void registerAppSyncRequester(AppSyncRequester? requester) {
  _appSyncRequester = requester;
}

Future<void> requestAppSync({String trigger = 'unknown'}) async {
  final requester = _appSyncRequester;
  if (requester == null) {
    AppLogger.instance.debug(
      LogTags.sync,
      'requestAppSync($trigger): no requester registered, skipping',
    );
    return;
  }
  AppLogger.instance.info(LogTags.sync, 'requestAppSync($trigger)');
  await requester();
}

void scheduleAppSync({String trigger = 'unknown'}) {
  final requester = _appSyncRequester;
  if (requester == null) {
    AppLogger.instance.debug(
      LogTags.sync,
      'scheduleAppSync($trigger): no requester registered, skipping',
    );
    return;
  }
  AppLogger.instance.info(LogTags.sync, 'scheduleAppSync($trigger)');
  requester();
}
