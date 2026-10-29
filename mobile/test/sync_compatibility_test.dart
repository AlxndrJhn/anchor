import 'package:anchor/core/network/anchor_protocol.dart';
import 'package:anchor/features/server/data/server_info_provider.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/sync/presentation/compatibility_messages.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  group('compatibilityFor', () {
    test('syncs when the server advertises our protocol', () {
      expect(compatibilityFor([anchorProtocol]), SyncCompatibility.ok);
    });

    test('syncs when our protocol sits inside the advertised range', () {
      expect(
        compatibilityFor([
          anchorProtocol - 1,
          anchorProtocol,
          anchorProtocol + 1,
        ]),
        SyncCompatibility.ok,
      );
    });

    test('blames the app when every server protocol is ahead', () {
      expect(
        compatibilityFor([anchorProtocol + 1, anchorProtocol + 2]),
        SyncCompatibility.appOutdated,
      );
    });

    test('blames the server when every server protocol is behind', () {
      expect(
        compatibilityFor([anchorProtocol - 2, anchorProtocol - 1]),
        SyncCompatibility.serverOutdated,
      );
    });

    test('treats a server that advertises nothing as outdated', () {
      expect(compatibilityFor([]), SyncCompatibility.serverOutdated);
    });
  });

  group('compatibilityMessagesOf', () {
    test('a mismatch has something to show the user', () {
      for (final state in [
        SyncCompatibility.serverOutdated,
        SyncCompatibility.appOutdated,
      ]) {
        expect(state.isMismatch, isTrue);
        expect(compatibilityMessagesOf(state, _english), isNotNull);
      }
    });

    test('tells the side that is behind to update', () {
      expect(
        compatibilityMessagesOf(SyncCompatibility.appOutdated, _english)!.lead,
        'Update Anchor.',
      );
      expect(
        compatibilityMessagesOf(
          SyncCompatibility.serverOutdated,
          _english,
        )!.lead,
        'Update your server.',
      );
    });

    test('a working or unknown server says nothing', () {
      for (final state in [
        SyncCompatibility.ok,
        SyncCompatibility.unreachable,
      ]) {
        expect(state.isMismatch, isFalse);
        expect(compatibilityMessagesOf(state, _english), isNull);
      }
    });
  });

  group('ServerInfo.fromJson', () {
    test('reads the advertised protocols', () {
      final info = ServerInfo.fromJson({
        'app': 'anchor',
        'version': '0.16.0',
        'protocols': [3, 4],
      });

      expect(info.protocols, [3, 4]);
      expect(compatibilityFor(info.protocols), SyncCompatibility.ok);
    });

    test('falls back to no protocols on a server that omits them', () {
      final info = ServerInfo.fromJson({'app': 'anchor', 'version': '0.9.0'});

      expect(info.protocols, isEmpty);
      expect(
        compatibilityFor(info.protocols),
        SyncCompatibility.serverOutdated,
      );
    });
  });
}
