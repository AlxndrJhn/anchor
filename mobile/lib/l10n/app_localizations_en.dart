// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonMenu => 'Menu';

  @override
  String get commonCloseMenu => 'Close menu';

  @override
  String get commonShowPassword => 'Show password';

  @override
  String get commonHidePassword => 'Hide password';

  @override
  String get commonSelectedNotes => 'Selected notes';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonPause => 'Pause';

  @override
  String commonPlayItem(String name) {
    return 'Play $name';
  }

  @override
  String commonPauseItem(String name) {
    return 'Pause $name';
  }

  @override
  String commonSwitchOn(String label) {
    return '$label, on';
  }

  @override
  String commonSwitchOff(String label) {
    return '$label, off';
  }

  @override
  String get formOffline =>
      'You’re offline. Connect to the internet to continue.';

  @override
  String get linkInvalid => 'Invalid link';

  @override
  String get linkCantOpen => 'Couldn’t open link';

  @override
  String get densityDefault => 'Default';

  @override
  String get densityCompact => 'Compact';

  @override
  String get noteFontSans => 'Sans';

  @override
  String get noteFontSerif => 'Serif';

  @override
  String get noteFontMono => 'Mono';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeDefault => 'Default';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get errorOffline => 'No internet connection.';

  @override
  String get errorTimeout => 'The server took too long to respond.';

  @override
  String get errorCertificate => 'The server’s certificate isn’t trusted.';

  @override
  String get errorCancelled => 'The request was canceled.';

  @override
  String get errorSignInAgain => 'Sign in again to continue.';

  @override
  String get errorForbidden => 'You don’t have permission to do that.';

  @override
  String get errorNotFound => 'The item couldn’t be found.';

  @override
  String get errorIncompatible =>
      'This app and your server aren’t compatible. Update them to continue.';

  @override
  String get errorCheckInput => 'Check the information you entered.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get errorServer => 'The server ran into a problem. Try again later.';

  @override
  String passwordHelp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At least $count characters.',
      one: 'At least 1 character.',
    );
    return '$_temp0';
  }

  @override
  String settingsSignOutMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes haven’t synced yet. They stay on this phone and sync when you sign in again.',
      one:
          '1 change hasn’t synced yet. It stays on this phone and syncs when you sign in again.',
      zero: 'Your notes stay on this phone and sync again when you sign in.',
    );
    return '$_temp0';
  }

  @override
  String logsCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count logs copied',
      one: '1 log copied',
    );
    return '$_temp0';
  }

  @override
  String get voiceNote => 'Voice note';
}
