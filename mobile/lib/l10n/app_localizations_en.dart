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
  String get commonSave => 'Save';

  @override
  String get commonUndo => 'Undo';

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
  String get authSignIn => 'Sign in';

  @override
  String get commonCopy => 'Copy';

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
  String get commonLater => 'Later';

  @override
  String get commonOk => 'OK';

  @override
  String get reminderTitle => 'Reminder';

  @override
  String get reminderChannelName => 'Reminders';

  @override
  String get reminderChannelDescription => 'Reminders you set on your notes';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get syncSignedOutLead => 'Signed out.';

  @override
  String get syncSignedOutText => 'Sign in again to sync your notes.';

  @override
  String get syncSignInAgainTitle => 'Sign in again';

  @override
  String get syncSignInAgainMessage =>
      'Your notes stay on this phone and sync once you sign in.';

  @override
  String get syncServerOutdatedLead => 'Update your server.';

  @override
  String get syncServerOutdatedText => 'It’s too old to sync with this app.';

  @override
  String get syncServerOutdatedTitle => 'Update your server';

  @override
  String get syncServerOutdatedMessage =>
      'Your Anchor server is too old to sync with this app. Update the server to continue.';

  @override
  String get syncAppOutdatedLead => 'Update Anchor.';

  @override
  String get syncAppOutdatedText =>
      'This app is too old to sync with your server.';

  @override
  String get syncAppOutdatedTitle => 'Update Anchor';

  @override
  String get syncAppOutdatedMessage =>
      'This app is too old to sync with your Anchor server. Update the app to continue.';

  @override
  String syncPausedMessage(String reason) {
    return '$reason Your notes stay on this phone in the meantime.';
  }

  @override
  String get starterAttachment => 'Picture or audio';

  @override
  String get attachmentAddLabel => 'Add picture or audio';

  @override
  String get lineText => 'Text';

  @override
  String get lineH1 => 'Heading 1';

  @override
  String get lineH2 => 'Heading 2';

  @override
  String get lineH3 => 'Heading 3';

  @override
  String get lineChecklist => 'Checklist';

  @override
  String get lineBullet => 'Bullet list';

  @override
  String get lineNumbered => 'Numbered list';

  @override
  String get lineQuote => 'Quote';

  @override
  String get lineCode => 'Code block';

  @override
  String get editorLink => 'Link';

  @override
  String get slashWordsChecklist => 'todo to-do task checkbox list';

  @override
  String get slashWordsH1 => 'h1 title';

  @override
  String get slashWordsH2 => 'h2 subtitle subheading';

  @override
  String get slashWordsH3 => 'h3 subheading';

  @override
  String get slashWordsBullet => 'unordered ul dashes';

  @override
  String get slashWordsNumbered => 'ordered ol';

  @override
  String get slashWordsQuote => 'blockquote citation';

  @override
  String get slashWordsCode => 'pre snippet';

  @override
  String get slashWordsText => 'paragraph plain normal body';

  @override
  String get slashWordsLink => 'url web address';

  @override
  String get slashWordsAttachment =>
      'image img photo file voice recording attachment';

  @override
  String get barFormatting => 'Formatting';

  @override
  String get barList => 'List';

  @override
  String get barSelected => 'Selected text';

  @override
  String get barStyles => 'Text styles';

  @override
  String get barColors => 'Highlight colors';

  @override
  String get barLineStyles => 'Line styles';

  @override
  String get toolOutdent => 'Outdent';

  @override
  String get toolIndent => 'Indent';

  @override
  String get toolBold => 'Bold';

  @override
  String get toolItalic => 'Italic';

  @override
  String get toolUnderline => 'Underline';

  @override
  String get toolStrikethrough => 'Strikethrough';

  @override
  String get toolHighlight => 'Highlight';

  @override
  String get toolRemoveHighlight => 'Remove highlight';

  @override
  String get toolRedo => 'Redo';

  @override
  String get toolHideKeyboard => 'Hide keyboard';

  @override
  String get editorEmptyItem => 'Empty item';

  @override
  String get editorLinkCopied => 'Link copied';

  @override
  String editorCheckedItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checked items',
      one: '1 checked item',
    );
    return '$_temp0';
  }

  @override
  String get linkAdd => 'Add link';

  @override
  String get linkEdit => 'Edit link';

  @override
  String get linkTextHint => 'Text';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRemove => 'Remove';

  @override
  String get editorSlashHint => 'Type / for more';

  @override
  String get editorPlaceholder => 'Start writing';

  @override
  String get voiceNote => 'Voice note';

  @override
  String get editorDragHint => 'Drag to reorder';

  @override
  String get slashMenuLabel => 'Insert';

  @override
  String get slashNoResults => 'No results';
}
