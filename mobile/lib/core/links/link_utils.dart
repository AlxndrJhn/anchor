import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../widgets/app_snackbar.dart';

const _schemes = [
  'http://',
  'https://',
  'mailto:',
  'tel:',
  'sms:',
  'ftp://',
  'ftps://',
  'file://',
  'geo:',
];

final _hostLike = RegExp(
  r'^([\w-]+(\.[\w-]+)+|localhost)(:\d+)?([/?#].*)?$',
  caseSensitive: false,
);

final _ipv4 = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

final _letter = RegExp('[a-z]', caseSensitive: false);

final _space = RegExp(r'\s');

final _email = RegExp(
  r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-z]{2,}$',
  caseSensitive: false,
);

final _bareScheme = RegExp(r'^[a-z]+:/*$', caseSensitive: false);

final _openers = RegExp(r'''^[("'<\[{“‘]*''');
final _closers = RegExp(r'''[.,;:!?'">\]}”’]+$''');

/// Only a full dotted quad counts as a numeric host.
bool _isHostLike(String text) {
  if (!_hostLike.hasMatch(text)) return false;
  final host = text.split(RegExp('[/?#:]')).first;
  return _letter.hasMatch(host) || _ipv4.hasMatch(host);
}

bool _hasScheme(String text) {
  final lower = text.toLowerCase();
  return _schemes.any(lower.startsWith);
}

String normalizeUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || _hasScheme(trimmed)) return trimmed;
  if (_isHostLike(trimmed)) return 'https://$trimmed';
  return trimmed;
}

bool isLikelyUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || _space.hasMatch(trimmed)) return false;
  return _hasScheme(trimmed) || _isHostLike(trimmed);
}

/// An address written with its scheme, or starting with "www.".
bool isFullUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || _space.hasMatch(trimmed)) return false;
  if (_hasScheme(trimmed)) return true;
  return trimmed.toLowerCase().startsWith('www.') && _isHostLike(trimmed);
}

/// [run], a stretch of text with no spaces, without the punctuation around
/// it; null when nothing is left.
({int start, String text})? wordIn(String run) {
  final start = _openers.firstMatch(run)!.end;
  var word = run.substring(start).replaceFirst(_closers, '');
  while (word.endsWith(')') &&
      ')'.allMatches(word).length > '('.allMatches(word).length) {
    word = word.substring(0, word.length - 1);
  }
  return word.isEmpty ? null : (start: start, text: word);
}

/// Null for anything else, like a bare example.com.
String? linkForTypedAddress(String word) {
  if (_bareScheme.hasMatch(word)) return null;
  if (isFullUrl(word)) return normalizeUrl(word);
  return _email.hasMatch(word) ? 'mailto:$word' : null;
}

Future<void> launchExternal(BuildContext context, String url) async {
  final normalized = normalizeUrl(url);
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        context.l10n.linkInvalid,
        kind: SnackbarKind.error,
      );
    }
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackbar.show(
        context,
        context.l10n.linkCantOpen,
        kind: SnackbarKind.error,
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppSnackbar.show(
        context,
        context.l10n.linkCantOpen,
        kind: SnackbarKind.error,
      );
    }
  }
}
