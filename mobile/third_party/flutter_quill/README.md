# flutter_quill 11.6.0, patched for Anchor+

The `lib/`, `pubspec.yaml` and `LICENSE` of
[flutter_quill 11.6.0](https://pub.dev/packages/flutter_quill/versions/11.6.0),
the app's editor, with one change: each line is laid out in its own text
direction. A line without a `direction` attribute takes it from its first
strong character, like `dir="auto"` on the web, so a Hebrew or Arabic
paragraph is right-to-left and right-aligned while English lines in the same
note stay left-to-right. Nothing is stored, so notes from the web and from
sync need no migration.

Upstream reads the direction only from the attribute, and even then gives
top-level lines and list items the editor's direction for their text; a
right-to-left line's checkbox is painted at its right but taps reach its
left. Every change is marked with an `Anchor+` comment:

- `lib/src/common/utils/paragraph_direction.dart` (new, exported from
  `lib/flutter_quill.dart`): the first strong character's direction. The
  note cards use it too.
- `lib/src/delta/delta_diff.dart`: `getDirectionOfNode` falls back to it.
  Code blocks keep the editor's direction.
- `lib/src/editor/raw_editor/raw_editor_state.dart` and
  `lib/src/editor/widgets/text/text_block.dart`: lines and list items use
  their own direction.
- `lib/src/editor/widgets/text/text_line.dart`: a line's leading (checkbox,
  bullet, number) is laid out where it is painted.
- `pubspec.yaml`: `publish_to: none`, without upstream's screenshots.

To move to a newer flutter_quill, copy its `lib/`, `pubspec.yaml` and
`LICENSE` here and apply the changes again (the commit after "Vendor
flutter_quill 11.6.0, unchanged" holds them as one diff), or go back to the
pub.dev package in `mobile/pubspec.yaml` once upstream handles it.
