# Anchor+ Privacy Policy

_Last updated: November 11, 2026_

This policy covers the Anchor+ apps for Android and iOS ("the app"), published
by AlxndrJhn, the developer of the open source
[Anchor+ project](https://github.com/AlxndrJhn/anchor-plus).

## The short version

- The developer collects **no** data about you: no analytics, no ads, no
  tracking, no account with us.
- Your notes are stored on your device. If you connect the app to an Anchor+
  server, they are also sent to **that server only**: one that you, or someone
  you chose, runs.
- You can delete everything at any time.

## What the app stores on your device

Your notes, checklists, tags, pictures, recordings, attachments, reminders and
settings are stored in the app's private storage on your device. Your sign-in
token for a server is kept in the system's secure storage (Android Keystore,
iOS Keychain). Uninstalling the app, or clearing its data, deletes all of it.

## What the app sends, and where

The app works without any server. If you choose to connect one (Settings ›
Connect to a server), the app sends the following to the address you entered,
and nowhere else:

- your account details (name, email address, password or sign-in code) when
  you register or sign in;
- your notes, tags, pictures, recordings and attachments, to sync them across
  your devices and to share notes you choose to share;
- the camera picture and sound of a live image you turn on, to the people who
  open that note.

That server is not run by the developer of Anchor+. Its operator (you, your
organisation or whoever you chose) is responsible for the data on it and for
its own privacy practices. Server accounts and the notes in them are deleted
by that server's operator, or by you in the server's settings where it offers
that.

## Third-party services

- **Text recognition (Google ML Kit).** "Grab image text" reads the text in a
  picture on the device, with Google's ML Kit. The picture does not leave
  your device for this. ML Kit may send Google anonymous information about
  its own use and performance (such as the device model and how long a
  recognition took), as described in
  [Google's ML Kit data disclosure](https://developers.google.com/ml-kit/android-data-disclosure).
- **Links you open.** Links in notes, the project page and bug reports open in
  your browser, under that site's own privacy policy. A bug report you choose
  to file from the app's debug mode is opened as a GitHub issue that you can
  read and edit before sending.

The app contains no advertising, analytics or crash-reporting services.

## Permissions

The app asks for a permission only when you use the feature that needs it:

| Permission | Used for |
|---|---|
| Camera | Taking pictures for notes and your profile photo; live images |
| Microphone | Voice recordings; the sound of a live image |
| Photos | Adding pictures to notes and saving pictures from notes |
| Notifications, alarms | Reminders you set |
| Face ID, Touch ID, fingerprint | Opening notes you lock |
| Local network (iOS) | Reaching your server when it is on your home network |

## Children

The app is not directed at children under 13 and does not knowingly collect
data from anyone.

## Security

Connections to a server use HTTPS when the server offers it. Notes you lock
open only with your fingerprint, face or device passcode. Keep your device
and your server up to date.

## Changes

Changes to this policy are published in this file; its history is in the
[project's repository](https://github.com/AlxndrJhn/anchor-plus/commits/main/store/privacy-policy.md).

## Contact

Questions about this policy:
[open an issue](https://github.com/AlxndrJhn/anchor-plus/issues) on the
project page.
