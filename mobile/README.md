# Anchor Mobile App

This is the Flutter mobile application for Anchor, a self-hosted note-taking platform.

## Features

-   **Offline-First**: Create and edit notes without an internet connection.
-   **Attachments**: Attach images and audio recordings to notes.
-   **Rich Text Editor**: Format your thoughts with bold, italic, lists, and more using Flutter Quill.
-   **Sync**: Automatic bidirectional sync with the self-hosted server when online.
-   **Home Screen Widget**: View your notes from the Android home screen, and tap to open one or start a new note.
-   **Secure**: JWT authentication and secure local storage.
-   **Theming**: Beautiful light and dark mode support.
-   **Search**: Instant local search.

## Tech Stack

-   **Flutter**: UI Framework
-   **Riverpod**: State Management
-   **Drift**: Local SQLite Database
-   **GoRouter**: Navigation
-   **Dio**: HTTP Client
-   **Flutter Quill**: Rich Text Editor

## Getting Started

### Prerequisites

-   [Flutter SDK](https://flutter.dev/docs/get-started/install) installed and configured.
-   An Android or iOS device/emulator.
-   A running instance of the Anchor Server (see root README).

### Installation

1.  Navigate to the mobile directory:
    ```bash
    cd mobile
    ```

2.  Install dependencies:
    ```bash
    flutter pub get
    ```

3.  Run code generation (for Riverpod, Drift, JSON serialization):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  Run the app:
    ```bash
    flutter run
    ```

### Connecting to Server

On the first launch, the app will ask for your **Server URL**.
-   If running locally on Android Emulator, use `http://10.0.2.2:3000`
-   If running locally on iOS Simulator, use `http://localhost:3000`
-   If self-hosted, use your deployed URL (e.g., `https://anchor.yourdomain.com`)

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Debug Reports

Hold two fingers still on the screen for 3 seconds to start debug mode: the
app films itself and notes what happens meanwhile: screen changes, touches,
provider updates and log lines.

A recording lasts at most 20 seconds. The ring around the red camera in the top
left corner shows the time left; when it closes, recording stops by itself. Tap
the camera to stop sooner. The limit keeps the frames held in memory (5 per
second) and the report file small; change it with `DebugRecorder.maxDuration`
in `lib/features/debug_recorder/data/debug_recorder_controller.dart`.

In the player that opens afterwards, move to where it
went wrong, tap **Problem here** and say what you expected. **Create issue**
saves `anchor-debug-<ISO time>.mp4` and opens a new GitHub issue on the fork,
to attach it to.

The file is one MP4: a Motion-JPEG video track, a timed metadata track
(`application/json`) with every event and problem at its time, and a summary
document holding all of it (app, device, problems, events) as the
`com.anchor.debug` metadata tag:

```bash
ffprobe -v quiet -show_entries format_tags=com.anchor.debug -of json \
  anchor-debug-2026-10-28T14-03-22Z.mp4 | jq -r '.format.tags["com.anchor.debug"]'
# The events track on its own, as JSON arrays one after another:
ffmpeg -v error -i anchor-debug-2026-10-28T14-03-22Z.mp4 -map 0:d -c copy -f data -
```
