# Releasing Anchor+ on Google Play and the App Store

The release workflow (`.github/workflows/release.yml`) can hand each release's
mobile app to the stores: `.github/workflows/stores.yml` builds it for Google
Play (an app bundle) and the App Store (an archive, signed and uploaded to
App Store Connect), and puts it on their **testing** tracks: Play's internal
track and TestFlight. Promoting a build to production, and everything a store
asks before the first review, happens in the Play Console and App Store
Connect, with the texts in this folder.

| File | What it is |
|---|---|
| `play/en-US/` | Play listing: title (30), short description (80), full description (4000), release notes |
| `app-store/en-US/` | App Store listing: name (30), subtitle (30), keywords (100), promotional text (170), description (4000), URLs, release notes |
| `privacy-policy.md` | The privacy policy both stores ask for. Its URL: `https://github.com/AlxndrJhn/anchor-plus/blob/main/store/privacy-policy.md` |

The file names follow fastlane's `supply`/`deliver` layout, so they can be
uploaded with fastlane later; for now, paste them in.

## How the store builds differ

- **No GitHub updater.** They are built without `UPDATE_REPO`, so Settings ›
  Updates doesn't appear, and the Play build drops `REQUEST_INSTALL_PACKAGES`
  (`ORG_GRADLE_PROJECT_storeBuild=true`, `mobile/android/app/src/store/`).
  Play doesn't allow an app to install its own updates.
- **Version numbers.** The version is `mobile/pubspec.yaml`'s (`0.18.0`). The
  build number is the release run's: on iOS as is, on Play as
  `10000 + run`, above every APK's version code, so a phone with the GitHub
  APK can move to the Play build if Play signs with the same key (below).
  The App Store only accepts a new version after the last approved one, so
  bump `version:` in `pubspec.yaml` before a release meant for the stores.
- **Named Anchor+** on both, like the released APKs.

## Before the first store release

These need a person with the store accounts. Items marked **blocker** will
get the app rejected until done.

### Blockers for both stores

1. **Account deletion in the app.** The app can create an account on a server
   (Register), and both Apple (guideline 5.1.1(v)) and Google Play (account
   deletion policy) then require a way to delete that account from inside the
   app, and Play also a web page for it. The server only lets admins delete
   users today. Add a self-service "Delete account" to the server API, the
   app's Settings and the web client.
2. **Screenshots.** Play: at least 2 phone screenshots, plus a 1024×500
   feature graphic and a 512×512 icon. App Store: 6.9" iPhone screenshots
   (1320×2868) and, since the app runs on iPad, 13" iPad ones (2064×2752).
   Take them from the store builds, without sample data that looks real.
3. **A demo server for review.** The app works without a server from the
   first start, which reviewers can try, but sync, sharing and sign-in need
   one. Stand one up (`install.sh`), make a demo account, and put its
   address and sign-in in the review notes (below).

### Also check

- **AGPL and the App Store.** Anchor+ is AGPL-3.0 and started from another
  project's code. The App Store's terms add restrictions the GPL family
  doesn't allow, which has been taken as a conflict before (VLC, 2011). If
  others hold copyright in the code, get their permission, or a licence
  exception, before publishing on the App Store. Google Play has no such
  conflict. (Not legal advice.)
- **Name.** Make sure "Anchor+ Notes" is free in both stores and doesn't
  suggest an affiliation with any other "Anchor" app (Play impersonation
  policy, App Store 4.1/5.2).
- **The iOS build has not run in CI yet.** The first `app-store` job may need
  fixes (signing, Swift packages). Run it by hand first (below).
- **iOS description.** `app-store/en-US/description.txt` is the Android
  feature list. Remove anything the iOS app doesn't do (widget, share
  sheet, recording while locked…) before submitting: Apple rejects listings
  that promise more than the app does (2.3.1).

## Google Play

1. **Developer account** at [play.google.com/console](https://play.google.com/console).
   A new *personal* account must run a closed test with at least 12 testers
   for 14 days before it can publish to production.
2. **Create the app**: Anchor+ Notes, app, free, package
   `com.alxndrjhn.anchorplus` (set by the first upload).
3. **Signing.** Play App Signing is required. Under *Test and release ›
   Setup › App signing*, choose to **use your own key** and upload the
   existing release keystore (the one in `ANDROID_KEYSTORE_BASE64`) with
   Google's PEPK tool. Then the Play build and the GitHub/F-Droid APKs share
   a signature, and people can move between them without reinstalling. If
   you let Google generate a key instead, the keystore is only the upload
   key and the two kinds of install can't update each other.
4. **First upload by hand.** Play's API can't create an app's first release.
   Run *Actions › App stores › Run workflow* on `main` with *play* only and a
   build number (e.g. the last release's run number), download the
   `anchor-plus-play-aab` artifact, and upload it under *Test and release ›
   Testing › Internal testing › Create new release*.
5. **API access for later uploads.** In Google Cloud, enable the *Google Play
   Android Developer API*, create a service account and a JSON key for it.
   In the Play Console, *Users and permissions › Invite new users*, invite the
   service account's email with *Release apps to testing tracks* and *Manage
   testing tracks* for this app. Then:

   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON --repo AlxndrJhn/anchor-plus < play-service-account.json
   ```

   ```bash
   gh variable set PLAY_UPLOADS --repo AlxndrJhn/anchor-plus --body true
   ```

   Uploads go to the internal track as drafts. Once the app is past its first
   review, set `PLAY_RELEASE_STATUS` to `completed` so they roll out to
   testers right away (and `PLAY_TRACK` to `alpha`/`beta` for a closed or open
   test):

   ```bash
   gh variable set PLAY_RELEASE_STATUS --repo AlxndrJhn/anchor-plus --body completed
   ```

6. **App content** (*Policy and programs › App content*):
   - **Privacy policy**: the URL above.
   - **Ads**: no ads.
   - **App access**: some functionality is restricted; give the demo server
     and account.
   - **Content rating** (IARC): utility/productivity; users can share content
     (public links), no purchases.
   - **Target audience**: 13 and over; not designed for children.
   - **Data safety**: see below.
   - **Foreground service permissions**: declare *camera* and *microphone*
     for live images and voice recordings that go on while the phone is
     locked, with a short video of each.
   - **Exact alarms**: `SCHEDULE_EXACT_ALARM` is asked for at the first
     reminder and needs no declaration; it serves reminders the user sets.
   - **Account deletion**: the in-app path and web URL (blocker 1).
7. **Store listing**: paste `play/en-US/`, the screenshots and graphics;
   category *Productivity*; contact email; website
   `https://github.com/AlxndrJhn/anchor-plus`.
8. **Promote** the internal release to closed testing, then production,
   when it is ready.

## App Store

1. **Apple Developer Program** membership for team `UHBRM2B854` (the team
   the Xcode project signs with).
2. **Identifiers** ([developer.apple.com › Certificates, IDs &
   Profiles](https://developer.apple.com/account/resources/identifiers/list)):
   App IDs `com.alxndrjhn.anchorplus` and
   `com.alxndrjhn.anchorplus.ShareExtension`, both with the *App Groups*
   capability set to `group.com.alxndrjhn.anchorplus`. Xcode can register
   them itself, but it is clearer to create them.
3. **Create the app** in [App Store Connect](https://appstoreconnect.apple.com)
   › Apps › New App: iOS, name *Anchor+ Notes*, English (U.S.), bundle ID
   `com.alxndrjhn.anchorplus`, any SKU.
4. **API key.** *Users and Access › Integrations › App Store Connect API ›
   Team Keys*, a key with the **Admin** role (Xcode needs it to sign with a
   cloud-managed distribution certificate). Download the `.p8` (only once)
   and note its Key ID and the Issuer ID.
5. **Development certificate.** In Xcode › Settings › Accounts › Manage
   Certificates, add an *Apple Development* certificate if there is none,
   then in Keychain Access export it with its private key as a `.p12` with a
   password. It signs the archive; the upload is re-signed for distribution.
6. **Secrets and switch** (on a Mac):

   ```bash
   gh secret set ASC_KEY_ID --repo AlxndrJhn/anchor-plus --body "<key id>"
   ```

   ```bash
   gh secret set ASC_ISSUER_ID --repo AlxndrJhn/anchor-plus --body "<issuer id>"
   ```

   ```bash
   base64 -i AuthKey_<key id>.p8 | gh secret set ASC_KEY_P8_BASE64 --repo AlxndrJhn/anchor-plus
   ```

   ```bash
   base64 -i development.p12 | gh secret set IOS_DEV_CERT_P12_BASE64 --repo AlxndrJhn/anchor-plus
   ```

   ```bash
   gh secret set IOS_DEV_CERT_PASSWORD --repo AlxndrJhn/anchor-plus --body "<p12 password>"
   ```

   Run *Actions › App stores › Run workflow* with *app_store* only to try it,
   then turn it on for releases:

   ```bash
   gh variable set APP_STORE_UPLOADS --repo AlxndrJhn/anchor-plus --body true
   ```

7. **TestFlight**: each upload appears there after Apple processes it
   (10–30 minutes). Internal testers get it at once; external testers after a
   short beta review.
8. **App information**: category *Productivity*; age rating questionnaire
   (no objectionable content; no unrestricted web access); privacy policy
   URL; **App Privacy** answers (below); export compliance is answered by
   `ITSAppUsesNonExemptEncryption = false` in `Info.plist` (HTTPS only).
9. **Version page**: paste `app-store/en-US/`, the screenshots, pick the
   TestFlight build, and fill in **App Review Information**:

   > Anchor+ works without a server: notes are kept on the device. (If the
   > sign-in screen shows, tap "Use without a server" at its bottom.)
   > To try syncing, sharing and sign-in, connect to our demo server:
   > Settings › Connect to a server › `<https://demo.example>`, user
   > `<demo user>`, password `<demo password>`.

   Then *Add for Review*.

## Privacy answers

Notes only go to the server the user connects, which the developer doesn't
run or have access to; the app has no analytics, ads or crash reporting.
The one third party is Google's ML Kit (on-device text recognition), which
may send Google anonymous usage and performance data.

**App Store › App Privacy.** Apple counts data as collected when the
developer or its partners can get at it, which the user's own server isn't.
Answer *Data Not Collected* for the app's own data, and declare for ML Kit:
*Diagnostics › Performance Data* and *Other Diagnostic Data*: not linked to
the user, not used for tracking, purpose *App Functionality*. Check
[Google's ML Kit disclosure](https://developers.google.com/ml-kit/android-data-disclosure)
when submitting.

**Google Play › Data safety.** Play counts anything sent off the device,
even to a server the user picks. The safe answer:

| Data type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Personal info › Name, Email address | Yes | No | Yes (only with a server) | Account management |
| Photos and videos › Photos, Videos | Yes | No | Yes | App functionality |
| Audio › Voice or sound recordings | Yes | No | Yes | App functionality |
| Files and docs | Yes | No | Yes | App functionality |
| App activity › Other user-generated content (notes) | Yes | No | Yes | App functionality |
| App info and performance › Diagnostics (ML Kit) | Yes | No | No | Analytics |

- *Is data encrypted in transit?* Only answer yes if the app refuses plain
  `http://` servers; today it accepts them, so answer **No**.
- *Can users request deletion?* Yes, once blocker 1 is done.

## After each release

With `PLAY_UPLOADS` / `APP_STORE_UPLOADS` on, every release and release
candidate whose app changed goes to the internal track and TestFlight on its
own. To publish one: Play Console › promote the release to production (it is
reviewed, usually within a day); App Store Connect › new version (bumped in
`pubspec.yaml`), pick the build, add release notes, *Add for Review*.
