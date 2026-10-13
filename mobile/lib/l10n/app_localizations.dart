import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Screen reader label of the back arrow in the top bar and the editor toolbar.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button that closes a dialog, sheet, search or selection without making changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Spoken label of the picture viewer’s close button and of the area outside a dialog, and the button that closes the share sheet when nothing in a share can be saved.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Small button at the top of a sheet that closes it.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Screen reader name of a pop-up menu and of the side menu with the lists and tags.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get commonMenu;

  /// Screen reader label for the area outside an open menu, which closes it.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get commonCloseMenu;

  /// Screen reader label of the eye button that shows a hidden password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get commonShowPassword;

  /// Screen reader label of the eye button that hides a shown password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get commonHidePassword;

  /// Screen reader name of the bar shown while notes are selected.
  ///
  /// In en, this message translates to:
  /// **'Selected notes'**
  String get commonSelectedNotes;

  /// Screen reader label of a play button for an audio file without a name.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// Screen reader label of a pause button for an audio file without a name.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// Screen reader label of a play button for an audio or video file.
  ///
  /// In en, this message translates to:
  /// **'Play {name}'**
  String commonPlayItem(String name);

  /// Screen reader label of a pause button for an audio or video file.
  ///
  /// In en, this message translates to:
  /// **'Pause {name}'**
  String commonPauseItem(String name);

  /// Screen reader text for a settings switch that is on.
  ///
  /// In en, this message translates to:
  /// **'{label}, on'**
  String commonSwitchOn(String label);

  /// Screen reader text for a settings switch that is off.
  ///
  /// In en, this message translates to:
  /// **'{label}, off'**
  String commonSwitchOff(String label);

  /// Notice at the top of a form that needs the server.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. Connect to the internet to continue.'**
  String get formOffline;

  /// Message when a tapped link isn’t a valid web address.
  ///
  /// In en, this message translates to:
  /// **'Invalid link'**
  String get linkInvalid;

  /// Message when no app on the phone can open a tapped link.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open link'**
  String get linkCantOpen;

  /// Display density with regular spacing.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get densityDefault;

  /// Display density with tighter spacing that fits more notes.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get densityCompact;

  /// Note font choice: a sans-serif font.
  ///
  /// In en, this message translates to:
  /// **'Sans'**
  String get noteFontSans;

  /// Note font choice: a serif font.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get noteFontSerif;

  /// Note font choice: a monospaced font.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get noteFontMono;

  /// Note text size.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// Note text size.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get textSizeDefault;

  /// Note text size.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// Error when a request fails because the phone has no internet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorOffline;

  /// Error when the server doesn’t answer in time.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond.'**
  String get errorTimeout;

  /// Error when the server’s security certificate can’t be verified.
  ///
  /// In en, this message translates to:
  /// **'The server’s certificate isn’t trusted.'**
  String get errorCertificate;

  /// Error when a request to the server stopped before it finished.
  ///
  /// In en, this message translates to:
  /// **'The request was canceled.'**
  String get errorCancelled;

  /// Error when the person’s sign-in has expired and the server refuses the request.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get errorSignInAgain;

  /// Error when the server refuses an action this account isn’t allowed to do.
  ///
  /// In en, this message translates to:
  /// **'You don’t have permission to do that.'**
  String get errorForbidden;

  /// Error when the server can’t find what the app asked for.
  ///
  /// In en, this message translates to:
  /// **'The item couldn’t be found.'**
  String get errorNotFound;

  /// Error when the app and server versions can’t work together.
  ///
  /// In en, this message translates to:
  /// **'This app and your server aren’t compatible. Update them to continue.'**
  String get errorIncompatible;

  /// Error at the top of a form when the server rejects what was entered.
  ///
  /// In en, this message translates to:
  /// **'Check the information you entered.'**
  String get errorCheckInput;

  /// Error for any unexpected failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// Error when the server fails while handling a request.
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem. Try again later.'**
  String get errorServer;

  /// Shown under a new password field.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{At least 1 character.} other{At least {count} characters.}}'**
  String passwordHelp(int count);

  /// {count} is the number of changes not yet sent to the server.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Your notes stay on this phone and sync again when you sign in.} =1{1 change hasn’t synced yet. It stays on this phone and syncs when you sign in again.} other{{count} changes haven’t synced yet. They stay on this phone and sync when you sign in again.}}'**
  String settingsSignOutMessage(int count);

  /// Toast after the selected logs were copied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 log copied} other{{count} logs copied}}'**
  String logsCopied(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
