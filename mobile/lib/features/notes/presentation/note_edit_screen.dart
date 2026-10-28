import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:anchor/core/files/device_files.dart';
import 'package:anchor/core/logging/app_logger.dart';
import 'package:anchor/core/network/dio_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/network/sync_requester.dart';
import 'package:anchor/features/notes/domain/note_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:anchor/core/providers/active_user_id_provider.dart';
import 'package:anchor/core/router/app_routes.dart';
import 'package:anchor/core/share/share_handler.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:anchor/core/widgets/editor/link_utils.dart';
import 'package:anchor/core/widgets/confirm_dialog.dart';
import 'package:anchor/core/widgets/rich_text_editor.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/features/notes/domain/inline_image.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/multi_shot_camera_screen.dart';
import 'package:anchor/features/notes/presentation/widgets/inline_image_embed.dart';
import 'package:anchor/features/notes/presentation/widgets/note_attachments_gallery.dart';
import 'package:anchor/features/notes/presentation/widgets/note_audio_recorder_sheet.dart';
import 'package:anchor/features/notes/presentation/widgets/note_background.dart';
import 'package:anchor/features/notes/presentation/widgets/note_background_picker.dart';
import 'package:anchor/features/notes/presentation/widgets/note_options_sheet.dart';
import 'package:anchor/features/notes/presentation/widgets/share_note_sheet.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_actions.dart';
import 'package:anchor/features/notes/presentation/note_freeze_actions.dart';
import 'package:anchor/features/settings/presentation/controllers/editor_preferences_controller.dart';
import 'package:anchor/features/tags/presentation/widgets/tag_selector.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:anchor/core/search/search_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show BlockEmbed;
import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../data/repository/notes_repository.dart';
import 'package:anchor/core/notifications/reminder_permission_prompt.dart';
import 'widgets/reminder_chip.dart';
import 'widgets/reminder_picker_sheet.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/tokens/app_icon_sizes.dart';
import 'package:anchor/core/theme/tokens/app_radius.dart';
import 'package:anchor/core/widgets/app_bottom_sheet.dart';

/// Where the caret was in a note, to open it there again.
class NoteCaret {
  const NoteCaret({required this.inTitle, required this.selection});

  final bool inTitle;
  final TextSelection selection;
}

class NoteEditScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final Note? note;

  /// A tag a new note starts with.
  final String? initialTagId;

  /// A search the note was opened from, marked in its text.
  final String? highlightTerm;

  /// How [highlightTerm] is read, as the search that found the note.
  final SearchOptions highlightOptions;

  /// What another app shared, which a new note starts with.
  final SharedContent? shared;

  /// A new note starts as a checklist (the "New checklist" app shortcut).
  final bool startAsChecklist;

  /// Starts the new note with the clipboard's text (New Note double-tapped).
  final bool pasteClipboard;

  /// Starts the new note by taking a picture into it (Camera note).
  final bool takePicture;

  /// The note opens with the caret here (its trash undone).
  final NoteCaret? caret;
  const NoteEditScreen({
    super.key,
    this.noteId,
    this.note,
    this.initialTagId,
    this.highlightTerm,
    this.highlightOptions = const SearchOptions(),
    this.shared,
    this.startAsChecklist = false,
    this.pasteClipboard = false,
    this.takePicture = false,
    this.caret,
  });

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _editorKey = GlobalKey<RichTextEditorState>();

  bool _isNew = true;
  bool _isDeleted = false;
  bool _isLoaded = false;
  bool _isEditing = false;
  bool _allowPop = false;
  bool _isHandlingPop = false;
  bool _isPinned = false;
  bool _isArchived = false;
  Note? _existingNote;
  String? _initialContent;
  List<String> _selectedTagIds = [];
  String? _selectedBackground;

  bool get _isActive => _existingNote?.isActive ?? true;

  // Frozen notes read like a viewer's: only what is this person's changes.
  bool get _isReadOnly => !_isActive || !(_existingNote?.canEdit ?? true);

  bool get _isFrozen => _existingNote?.isFrozen ?? false;

  /// Frozen by this person: it can't be trashed until they unfreeze it.
  bool get _isOwnFrozen => _existingNote?.isOwnFrozen ?? false;

  bool get _savesOnlyPersonal => !(_existingNote?.canEdit ?? true);

  String? get _noteId => widget.noteId ?? _existingNote?.id;

  Timer? _autoSaveTimer;
  StreamSubscription<Note?>? _noteWatch;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String _lastTitleText = '';

  /// Whether the caret was last in the title or the text; null until either
  /// has had focus.
  bool? _caretInTitle;

  String get _editorContent =>
      _editorKey.currentState?.getContent() ?? _initialContent ?? '';

  /// The attachments shown as pictures in the text, kept out of the gallery.
  Set<String> _inlineIds = const {};

  late final InlineImages _inlineImages;
  late final _embedBuilders = [InlineImageEmbedBuilder(_inlineImages)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inlineImages = InlineImages(
      repo: ref.read(noteAttachmentsRepositoryProvider),
      noteId: () => _noteId,
    );

    final watchedId = widget.note?.id ?? widget.noteId;
    if (watchedId != null) {
      _watchNote(watchedId);
    }

    if (widget.note != null) {
      _isNew = false;
      _existingNote = widget.note;
      _isPinned = widget.note!.isPinned;
      _isArchived = widget.note!.isArchived;
      _lastTitleText = widget.note!.title;
      _titleController.text = widget.note!.title;
      _initialContent = widget.note!.content;
      _inlineIds = inlineImageIds(_initialContent);
      _selectedTagIds = List.from(widget.note!.tagIds);
      _selectedBackground = widget.note!.background;
      _isLoaded = true;
      if (!widget.note!.isActive || !widget.note!.canEdit) {
        _isEditing = false;
      }
      _placeCaretOnceShown();
    } else if (widget.noteId != null) {
      _isNew = false;
      _loadNote();
    } else {
      _isEditing = true;
      _isPinned = false;
      _isLoaded = true;
      if (widget.initialTagId != null) _selectedTagIds = [widget.initialTagId!];
      final shared = widget.shared;
      if (shared != null) {
        if (shared.title != null) {
          _lastTitleText = shared.title!;
          _titleController.text = shared.title!;
        }
        if (shared.text != null) _initialContent = _sharedText(shared.text!);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _receiveShared(shared),
        );
      } else {
        if (widget.startAsChecklist) _initialContent = _emptyChecklist;
        // A new note opens with the caret in its text, ready to type.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.pasteClipboard) {
            _pasteClipboard();
          } else if (widget.takePicture) {
            _picturesIntoText(fromCamera: true);
          } else {
            _editorKey.currentState?.focusStart();
          }
        });
      }
    }

    _titleFocusNode.addListener(_updateEditingState);
    _titleController.addListener(_onTitleChanged);
  }

  void _updateEditingState() {
    final titleEditing = _titleFocusNode.hasFocus;
    final editorEditing = _editorKey.currentState?.isEditing ?? false;
    if (titleEditing || editorEditing) _caretInTitle = titleEditing;
    final newEditingState = _isReadOnly
        ? false
        : (titleEditing || editorEditing);

    if (_isEditing != newEditingState) {
      setState(() {
        _isEditing = newEditingState;
      });
    }
    _inlineImages.editing.value = !_isReadOnly && editorEditing;
  }

  void _watchNote(String id) {
    _noteWatch?.cancel();
    _noteWatch = ref
        .read(notesRepositoryProvider)
        .watchNote(id)
        .listen(_onStoredNoteChanged);
  }

  /// The stored note changed under us. It replaces what is on screen unless
  /// there is an unsaved edit, which stays and goes up on the next save.
  void _onStoredNoteChanged(Note? note) {
    if (!mounted) return;

    if (note == null) {
      _handleNoteGone();
      return;
    }

    final adopt = !_hasUnsavedChanges && !_isSaving && !_matchesEditor(note);

    setState(() {
      _existingNote = note;
      _isLoaded = true;
      if (!adopt) return;

      if (_titleController.text != note.title) {
        _lastTitleText = note.title;
        _titleController.text = note.title;
      }
      _initialContent = note.content;
      _inlineIds = inlineImageIds(note.content);
      _isPinned = note.isPinned;
      _isArchived = note.isArchived;
      _selectedTagIds = List.from(note.tagIds);
      _selectedBackground = note.background;
      if (!note.isActive || !note.canEdit) {
        _isEditing = false;
      }
    });
  }

  bool _matchesEditor(Note note) =>
      storedTitleOf(note.title) == storedTitleOf(_titleController.text) &&
      _editorHolds(note.content) &&
      note.isPinned == _isPinned &&
      note.isArchived == _isArchived &&
      note.background == _selectedBackground &&
      _listEquals(note.tagIds, _selectedTagIds);

  bool _editorHolds(String? content) =>
      _editorKey.currentState?.matchesContent(content) ??
      (content ?? '') == _editorContent;

  /// Deleted for good elsewhere, or a share that was revoked.
  void _handleNoteGone() {
    if (_isNew || _isDeleted) return;

    _isDeleted = true;
    _autoSaveTimer?.cancel();
    AppSnackbar.showError(context, message: 'This note is no longer available');
    _popOrExit();
  }

  Future<void> _loadNote() async {
    final note = await ref
        .read(notesRepositoryProvider)
        .getNote(widget.noteId!);
    if (note != null && mounted) {
      _lastTitleText = note.title;
      setState(() {
        _existingNote = note;
        _isPinned = note.isPinned;
        _isArchived = note.isArchived;
        _titleController.text = note.title;
        _initialContent = note.content;
        _inlineIds = inlineImageIds(note.content);
        _selectedTagIds = List.from(note.tagIds);
        _selectedBackground = note.background;
        _isLoaded = true;
        if (!note.isActive || !note.canEdit) {
          _isEditing = false;
        }
      });
      _placeCaretOnceShown();
    }
  }

  /// Back from an undone trash: the caret goes where it was.
  void _placeCaretOnceShown() {
    final caret = widget.caret;
    if (caret == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isReadOnly) return;
      if (!caret.inTitle) {
        _editorKey.currentState?.focusAt(caret.selection);
        return;
      }
      final end = _titleController.text.length;
      _titleController.selection = TextSelection(
        baseOffset: caret.selection.baseOffset.clamp(0, end),
        extentOffset: caret.selection.extentOffset.clamp(0, end),
      );
      _titleFocusNode.requestFocus();
    });
  }

  /// Where the caret is in the note, if it has been in it.
  NoteCaret? _readCaret() {
    final inTitle = _caretInTitle;
    if (inTitle == null) return null;
    final selection = inTitle
        ? _titleController.selection
        : _editorKey.currentState?.selection;
    if (selection == null || !selection.isValid) return null;
    return NoteCaret(inTitle: inTitle, selection: selection);
  }

  /// The title controller also notifies on selection changes; only text
  /// changes mark the note dirty.
  void _onTitleChanged() {
    if (_titleController.text == _lastTitleText) return;
    _lastTitleText = _titleController.text;
    _onContentChanged();
  }

  void _onContentChanged() {
    _hasUnsavedChanges = true;
    _resetAutoSaveTimer();
  }

  void _onEditorChanged() {
    _onContentChanged();
    final shown = {
      for (final data
          in _editorKey.currentState?.embedsOf(InlineImage.embedType) ??
              const [])
        ?InlineImage.tryParse(data)?.id,
    };
    if (!_setEquals(shown, _inlineIds)) setState(() => _inlineIds = shown);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.difference(b).isEmpty;
  }

  void _resetAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _autoSave();
    });
  }

  Future<void> _autoSave() async {
    if (!_hasUnsavedChanges) return;

    await _savePendingChanges();
  }

  Future<void> _savePendingChanges() async {
    // Cleared before saving so edits made during the await stay flagged.
    _hasUnsavedChanges = false;
    _isSaving = true;
    try {
      await _saveNote();
    } finally {
      _isSaving = false;
    }
  }

  /// Leaves the editor: pops when there is a screen beneath, or exits the
  /// app when the editor is the root (opened from the home widget).
  void _popOrExit([Object? result]) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _saveAndPop([Object? result]) async {
    if (_isHandlingPop) return;

    _isHandlingPop = true;
    _autoSaveTimer?.cancel();

    try {
      // _saveNote skips when no field changed.
      if (!_isDeleted) {
        await _savePendingChanges();
      }
    } finally {
      if (mounted) {
        setState(() {
          _allowPop = true;
        });
        _popOrExit(result);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_hasUnsavedChanges) {
        _autoSave();
      }
    }
  }

  Future<void> _togglePinned() async {
    final note = _existingNote;
    if (note == null || !note.isActive) {
      return;
    }
    setState(() {
      _isPinned = !_isPinned;
    });
    await ref.read(notesRepositoryProvider).bulkSetPinned([note.id], _isPinned);
  }

  Future<void> _toggleArchived() async {
    if (_isNew) return;

    final wasArchived = _isArchived;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.archive,
        iconColor: Theme.of(context).colorScheme.primary,
        title: wasArchived ? 'Unarchive note?' : 'Archive note?',
        message: wasArchived
            ? 'This note will be moved back to your notes.'
            : 'This note will be moved to archive.',
        cancelText: 'Cancel',
        confirmText: wasArchived ? 'Unarchive' : 'Archive',
        onConfirm: () {},
      ),
    );

    if (confirm != true || !mounted) return;

    final repository = ref.read(notesRepositoryProvider);
    try {
      if (wasArchived) {
        await repository.unarchiveNote(_noteId!);
      } else {
        await repository.archiveNote(_noteId!);
      }

      await _loadNote();

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: wasArchived ? 'Note unarchived' : 'Note archived',
        );

        if (!wasArchived) {
          // Small delay to ensure snackbar is visible
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _popOrExit();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: wasArchived
              ? 'Failed to unarchive note'
              : 'Failed to archive note',
        );
      }
    }
  }

  void _showColorPicker() {
    // New notes have no _existingNote yet but are always editable.
    if (!_isNew && _existingNote?.isActive != true) {
      return;
    }
    AppBottomSheet.show(
      context,
      builder: (context) => NoteBackgroundPicker(
        selectedColor: _selectedBackground,
        onColorChanged: (color) {
          setState(() {
            _selectedBackground = color;
          });
          _onContentChanged();
        },
      ),
    );
  }

  void _showShareSheet() {
    if (_isNew ||
        _existingNote?.isActive != true ||
        !(_existingNote?.isOwner ?? true)) {
      return;
    }
    AppBottomSheet.show(
      context,
      builder: (context) =>
          ShareNoteSheet(noteId: widget.noteId ?? _existingNote!.id),
    ).then((_) {
      if (widget.noteId != null || _existingNote != null) {
        _reloadNote();
      }
    });
  }

  void _showReminderPicker() {
    if (!_isActive) return;
    AppBottomSheet.show(
      context,
      // The sheet pops before this runs, so the snackbar needs the screen's
      // context.
      builder: (_) => ReminderPickerSheet(
        reminder: _existingNote?.reminder,
        onReminderChanged: (reminder) async {
          try {
            var noteId = widget.noteId ?? _existingNote?.id;
            noteId ??= await _createNote();

            await ref
                .read(notesRepositoryProvider)
                .setReminder(noteId, reminder);
            await _reloadNote();
            if (!mounted) return;
            AppSnackbar.showSuccess(
              context,
              message: reminder == null ? 'Reminder removed' : 'Reminder set',
            );
          } catch (_) {
            if (!mounted) return;
            AppSnackbar.showError(context, message: 'Failed to set reminder');
            return;
          }

          if (reminder != null && mounted) {
            await ensureReminderPermissions(
              context,
              ref,
              trigger: ReminderPermissionTrigger.userSet,
            );
          }
        },
      ),
    );
  }

  void _showAttachmentSheet() {
    AppBottomSheet.show(
      context,
      builder: (context) => NoteAttachmentSheet(
        onFilesSelected: _addAttachments,
        onTakeSeveral: _takeSeveralPictures,
      ),
    );
  }

  /// The server's limit for one file.
  static const _maxAttachmentBytes = 50 * 1024 * 1024;

  /// Attaches a file to the note and returns its id; null when it couldn't
  /// be, after saying why.
  Future<String?> _attach(
    String filePath,
    String mimeType,
    String filename,
  ) async {
    try {
      if (await File(filePath).length() > _maxAttachmentBytes) {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            message: 'Can\'t attach $filename: files can be up to 50 MB',
          );
        }
        return null;
      }
      // Attachments are keyed to a persisted note. For a brand-new note
      // the user may start by adding an attachment, so create the note
      // now that there's something to attach to.
      var noteId = widget.noteId ?? _existingNote?.id;
      noteId ??= await _createNote();
      final repo = ref.read(noteAttachmentsRepositoryProvider);
      return await repo.addAttachment(noteId, filePath, mimeType, filename);
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, message: 'Failed to add attachment');
      }
      return null;
    }
  }

  /// Attaches what was picked, then says how many went in.
  Future<void> _addAttachments(List<PickedAttachment> files) async {
    final zips = p.join((await getTemporaryDirectory()).path, 'folders');
    var added = 0;
    for (final file in files) {
      if (await _attach(file.path, file.mimeType, file.name) != null) added++;
      // A zipped folder was made for this; the attachment has its own copy.
      if (p.isWithin(zips, file.path)) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
      if (!mounted) return;
    }
    if (added == 0 || !mounted) return;
    AppSnackbar.showSuccess(
      context,
      message: added == 1 ? 'Attachment added' : '$added attachments added',
    );
  }

  static String _pictureName(String extension) =>
      'Picture ${DateFormat('yyyy-MM-dd-HH-mm-ss-SSS').format(DateTime.now())}'
      '$extension';

  static PickedAttachment _pickedPicture(XFile picture) {
    final ext = p.extension(picture.name).toLowerCase();
    return (
      path: picture.path,
      mimeType: mimeTypeFor(picture.name),
      name: _pictureName(ext.isEmpty ? '.jpg' : ext),
    );
  }

  /// "Take picture": one picture with the phone's camera app.
  Future<void> _takePicture() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera);
    if (shot == null || !mounted) return;
    await _addAttachments([_pickedPicture(shot)]);
  }

  /// "Add image": pictures from the gallery.
  Future<void> _addImages() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isEmpty || !mounted) return;
    await _addAttachments([for (final image in images) _pickedPicture(image)]);
  }

  /// "Take several": pictures one after another, without coming back to the
  /// note in between; each is attached as it's taken.
  Future<void> _takeSeveralPictures() async {
    final count = await MultiShotCameraScreen.open(
      context,
      onPicture: (shot) async {
        await _attach(shot.path, 'image/jpeg', _pictureName('.jpg'));
        try {
          await File(shot.path).delete();
        } catch (_) {}
      },
    );
    if (count == 0 || !mounted) return;
    AppSnackbar.showSuccess(
      context,
      message: count == 1 ? '1 picture added' : '$count pictures added',
    );
  }

  /// Pictures from the camera or the gallery, placed in the text where the
  /// caret was.
  Future<void> _picturesIntoText({required bool fromCamera}) async {
    final editor = _editorKey.currentState;
    if (editor == null || _isReadOnly) return;
    final at = editor.caretOffset;
    final picker = ImagePicker();
    final List<XFile> pictures;
    if (fromCamera) {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      pictures = [?shot];
    } else {
      pictures = await picker.pickMultiImage(imageQuality: 92);
    }
    if (pictures.isEmpty || !mounted) return;
    final ids = <String>[];
    for (final picture in pictures) {
      final picked = _pickedPicture(picture);
      final id = await _attach(picked.path, picked.mimeType, picked.name);
      if (!mounted) return;
      if (id != null) ids.add(id);
    }
    _editorKey.currentState?.insertBlockEmbeds([
      for (final id in ids)
        BlockEmbed(InlineImage.embedType, InlineImage(id: id).encode()),
    ], offset: at);
  }

  /// Shared text as note content; a lone link stays a link.
  static final _emptyChecklist = jsonEncode({
    'ops': [
      {
        'insert': '\n',
        'attributes': {'list': 'unchecked'},
      },
    ],
  });

  static String _sharedText(String text) => jsonEncode({
    'ops': isLikelyUrl(text)
        ? [
            {
              'insert': text,
              'attributes': {'link': text},
            },
            {'insert': '\n'},
          ]
        : [
            {'insert': '$text\n'},
          ],
  });

  /// Saves the shared note and attaches what was shared with it.
  Future<void> _receiveShared(SharedContent shared) async {
    if (!mounted) return;
    if (shared.title != null || shared.text != null) _onContentChanged();
    if (shared.files.isNotEmpty) {
      await _addAttachments([
        for (final file in shared.files)
          (path: file.path, mimeType: file.mimeType, name: file.name),
      ]);
    }
    for (final file in shared.files) {
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
  }

  /// A picture pasted from the keyboard or the selection menu goes into the
  /// text where the caret was, where a corner handle resizes it.
  Future<void> _onImageInserted(
    Uint8List bytes,
    String mimeType,
    int offset,
  ) async {
    if (_isReadOnly) return;
    final stamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());
    final ext = switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => 'png',
    };
    final filename = 'Pasted $stamp.$ext';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    final id = await _attach(file.path, mimeType, filename);
    try {
      await file.delete();
    } catch (_) {}
    if (id == null || !mounted) return;
    _editorKey.currentState?.insertBlockEmbeds([
      BlockEmbed(InlineImage.embedType, InlineImage(id: id).encode()),
    ], offset: offset);
  }

  void _showTagPicker() {
    if (!_isActive) return;
    AppBottomSheet.show(
      context,
      builder: (context) => TagPickerSheet(
        selectedTagIds: _selectedTagIds,
        onTagsChanged: (tagIds) {
          if (!_isActive) return;
          setState(() => _selectedTagIds = List.from(tagIds));
          if (_savesOnlyPersonal) {
            ref
                .read(notesRepositoryProvider)
                .setNoteTags(_existingNote!.id, tagIds);
            return;
          }
          _onContentChanged();
        },
      ),
    );
  }

  void _showOptionsSheet() {
    final editor = _editorKey.currentState;
    final checked = _isReadOnly ? 0 : (editor?.checkedItemCount ?? 0);
    // Saved notes, not in the trash, can be locked.
    final existing = _existingNote;
    final lockable = !_isNew && existing != null && !existing.isTrashed
        ? existing
        : null;
    AppBottomSheet.show(
      context,
      builder: (context) => NoteOptionsSheet(
        isReadOnly: _isReadOnly,
        isTrashed: _existingNote?.isTrashed ?? false,
        shareCount: _existingNote?.shareIds?.length ?? 0,
        onTagsTap: _showTagPicker,
        onBackgroundTap: _showColorPicker,
        onReminderTap: _showReminderPicker,
        onAttachmentTap: _showAttachmentSheet,
        onAddImageTap: _addImages,
        onTakePictureTap: _takePicture,
        onTakeSeveralTap: _takeSeveralPictures,
        onShareTap:
            !_isNew &&
                (_existingNote?.isActive ?? false) &&
                (_existingNote?.isOwner ?? true)
            ? _showShareSheet
            : null,
        onHistoryTap: !_isNew && (!_isReadOnly || _isFrozen)
            ? _openHistory
            : null,
        onSendTap: _sendNote,
        onCopyTap: !_isNew && !(_existingNote?.isTrashed ?? false)
            ? _copyNote
            : null,
        onShowCheckboxesTap:
            !_isReadOnly && (editor?.canShowCheckboxes ?? false)
            ? () => editor?.showCheckboxes()
            : null,
        onHideCheckboxesTap:
            !_isReadOnly &&
                !(editor?.canShowCheckboxes ?? true) &&
                (editor?.isAllChecklist ?? false)
            ? () => editor?.hideCheckboxes()
            : null,
        onLockTap: lockable == null
            ? null
            : () => lockOpenNote(context, ref, lockable),
        isLocked: lockable?.isLocked ?? false,
        onRemoveLockTap: lockable?.isLocked ?? false
            ? () => unlockOpenNote(context, ref, lockable!)
            : null,
        onFreezeTap: lockable != null && lockable.isOwner
            ? () => _setFrozen(!lockable.isFrozen)
            : null,
        isFrozen: _isFrozen,
        onUncheckAllTap: checked > 0 ? () => editor?.uncheckAll() : null,
        onRemoveCheckedTap: checked > 0
            ? () {
                editor?.removeChecked();
                AppSnackbar.showSuccess(
                  context,
                  message:
                      '${checked == 1 ? '1 ticked item' : '$checked ticked items'} deleted',
                );
              }
            : null,
      ),
    );
  }

  /// The clipboard's text, into the new note, with the caret after it.
  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final editor = _editorKey.currentState;
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) editor?.appendText(text);
    editor?.focusEnd();
  }

  /// Text read from one of the note's pictures goes at the end of the note.
  void _appendText(String text) {
    if (_isReadOnly) return;
    _editorKey.currentState?.appendText(text);
  }

  /// Hands the note to another app through Android's share sheet.
  Future<void> _sendNote() async {
    final text = noteToPlainText(_titleController.text, _editorContent);
    if (text.isEmpty) return;
    final title = storedTitleOf(_titleController.text);
    await SharePlus.instance.share(
      ShareParams(text: text, subject: title.isEmpty ? null : title),
    );
  }

  /// "Make a copy": the server copies the note with its attachments, then
  /// the copy opens. The note goes up first, so the copy has what's on screen.
  Future<void> _copyNote() async {
    final noteId = widget.noteId ?? _existingNote?.id;
    if (noteId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _saveNote();
      await requestAppSync(trigger: 'NoteEdit.copy');
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>('/api/notes/$noteId/copy');
      final copyId = response.data?['id'] as String?;
      await requestAppSync(trigger: 'NoteEdit.copied');
      if (!mounted || copyId == null) return;
      AppSnackbar.showSuccess(context, message: 'Copy made');
      context.go('/note/$copyId');
    } catch (e) {
      AppLogger.instance.warn('NoteEdit', 'Make a copy failed: $e');
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      AppSnackbar.showError(
        context,
        message: 'Couldn’t make a copy. It needs a connection to the server.',
      );
    }
  }

  /// Freezes or unfreezes the note; what is typed so far goes up first.
  Future<void> _setFrozen(bool isFrozen) async {
    final noteId = _noteId;
    if (noteId == null) return;
    _autoSaveTimer?.cancel();
    await _savePendingChanges();
    if (!mounted) return;
    await setNotesFrozen(context, ref, [noteId], isFrozen);
  }

  /// Sends what is typed so far before showing the versions.
  Future<void> _openHistory() async {
    final noteId = widget.noteId ?? _existingNote?.id;
    if (noteId == null) return;

    _autoSaveTimer?.cancel();
    await _savePendingChanges();
    if (!mounted) return;
    context.push('/note/$noteId/${AppRoutes.noteHistory}');
  }

  Future<void> _reloadNote() async {
    final noteId = widget.noteId ?? _existingNote?.id;
    if (noteId == null) return;

    final note = await ref.read(notesRepositoryProvider).getNote(noteId);
    if (note != null && mounted) {
      setState(() {
        _existingNote = note;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    unawaited(_noteWatch?.cancel());
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _titleFocusNode.removeListener(_updateEditingState);
    _titleFocusNode.dispose();
    _inlineImages.editing.dispose();
    super.dispose();
  }

  /// Creates and persists a note from the current editor fields, flipping the
  /// screen out of "new" mode. Returns the created note's id.
  Future<String> _createNote() async {
    final title = storedTitleOf(_titleController.text);
    final content = _editorKey.currentState?.getContent() ?? '';
    final newNote = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      isPinned: _isPinned,
      tagIds: _selectedTagIds,
      background: _selectedBackground,
      isSynced: false,
    );
    AppLogger.instance.info(
      'NoteEdit',
      '_createNote: id=${newNote.id} title.len=${newNote.title.length} '
          'content.len=${content.length} tags=${_selectedTagIds.length}',
    );
    await ref.read(notesRepositoryProvider).createNote(newNote);
    if (mounted) {
      setState(() {
        _isNew = false;
        _existingNote = newNote;
      });
      _watchNote(newNote.id);
    }
    return newNote.id;
  }

  Future<void> _saveNote() async {
    // New notes (_existingNote == null) are always treated as active/editable.
    final isActive =
        _existingNote == null || (_existingNote?.isActive ?? false);
    if (!isActive || !(_existingNote?.canEdit ?? true)) {
      return;
    }

    final title = storedTitleOf(_titleController.text);
    final editorState = _editorKey.currentState;
    final content = editorState?.getContent() ?? '';
    final plainText = editorState?.getPlainText() ?? '';

    // A note that was never created is only worth persisting once it holds
    // something.
    if (_isNew &&
        title.isEmpty &&
        plainText.isEmpty &&
        _selectedBackground == null &&
        !_isPinned) {
      AppLogger.instance.debug(
        'NoteEdit',
        '_saveNote: skipping empty new note',
      );
      return;
    }

    final repository = ref.read(notesRepositoryProvider);

    if (_isNew) {
      await _createNote();
    } else if (_existingNote != null) {
      final tagsChanged = !_listEquals(_existingNote!.tagIds, _selectedTagIds);
      final titleChanged = storedTitleOf(_existingNote!.title) != title;
      final contentChanged = !_editorHolds(_existingNote!.content);
      final pinChanged = _existingNote!.isPinned != _isPinned;
      final bgChanged = _existingNote!.background != _selectedBackground;
      if (!titleChanged &&
          !contentChanged &&
          !pinChanged &&
          !bgChanged &&
          !tagsChanged) {
        AppLogger.instance.debug(
          'NoteEdit',
          '_saveNote: no field changed for id=${_existingNote!.id}, skipping',
        );
        return;
      }

      AppLogger.instance.info(
        'NoteEdit',
        '_saveNote update: id=${_existingNote!.id} '
            'title=$titleChanged content=$contentChanged '
            '(${_existingNote!.content?.length ?? 0}→${content.length}) '
            'pin=$pinChanged bg=$bgChanged tags=$tagsChanged',
      );

      final updatedNote = _existingNote!.copyWith(
        title: titleChanged ? title : _existingNote!.title,
        content: contentChanged ? content : _existingNote!.content,
        isPinned: _isPinned,
        isArchived: _isArchived,
        tagIds: _selectedTagIds,
        background: _selectedBackground,
        isSynced: false,
      );
      await repository.updateNote(updatedNote);
      if (mounted) {
        setState(() {
          _existingNote = updatedNote;
        });
      }
    }
  }

  bool _listEquals(List<String> a, List<String> b) =>
      _setEquals(a.toSet(), b.toSet());

  Future<void> _deleteNote() async {
    if (_isNew) {
      _popOrExit();
      return;
    }
    if (_isOwnFrozen) return;

    final isOwner = _existingNote?.isOwner ?? true;
    // Your own note goes to trash at once, with Undo. A shared note asks
    // first: Undo can't bring it back, its owner has to share it again.
    if (!isOwner) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => ConfirmDialog(
          icon: LucideIcons.trash2,
          iconColor: Theme.of(context).colorScheme.error,
          title: 'Remove note?',
          message: 'This note will be removed from your notes.',
          cancelText: 'Cancel',
          confirmText: 'Remove',
          confirmColor: Theme.of(context).colorScheme.error,
          onConfirm: () {},
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final noteId = _noteId!;
    // Read now: the delete and Undo run after this screen has closed.
    final repo = ref.read(notesRepositoryProvider);
    final router = GoRouter.of(context);
    final caret = _readCaret();
    // With nothing to go back to, the app closes instead.
    final reopens = context.canPop();
    // Undo opens the note again, the caret where it was.
    Future<void> undo() async {
      await repo.restoreNote(noteId);
      if (reopens) router.push('/note/$noteId', extra: caret);
    }

    await _closeThenBurn(
      remove: () => repo.deleteNote(noteId),
      message: isOwner ? 'Note moved to trash' : 'Note removed',
      onUndo: isOwner ? undo : null,
    );
  }

  /// Closes the note at once; its card burns away in the list it goes back
  /// to, then [remove] deletes it and a message says so. With nothing to go
  /// back to, the app closes, so it's deleted first.
  Future<void> _closeThenBurn({
    required Future<void> Function() remove,
    required String message,
    VoidCallback? onUndo,
  }) async {
    final noteId = _noteId!;
    _isDeleted = true;
    if (!context.canPop()) {
      try {
        await remove();
      } catch (_) {
        _isDeleted = false;
        if (mounted) {
          AppSnackbar.showError(context, message: 'Failed to delete note');
        }
        return;
      }
      if (mounted) {
        AppSnackbar.showSuccess(context, message: message, onUndo: onUndo);
      }
      SystemNavigator.pop();
      return;
    }
    // Outlives this page, for the message once the note is gone.
    final host = Navigator.of(context).context;
    final closing =
        ModalRoute.of(context)?.reverseTransitionDuration ?? Duration.zero;
    context.pop();
    await Future<void>.delayed(closing);
    await burnNoteCards([noteId]);
    try {
      await remove();
    } catch (_) {
      restoreNoteCards([noteId]);
      if (host.mounted) {
        AppSnackbar.showError(host, message: 'Failed to delete note');
      }
      return;
    }
    if (host.mounted) {
      AppSnackbar.showSuccess(host, message: message, onUndo: onUndo);
    }
  }

  Future<void> _restoreNote() async {
    if (_isNew || _existingNote == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.rotateCcw,
        iconColor: Theme.of(context).colorScheme.primary,
        title: 'Restore note?',
        message: 'This note will be moved back to your notes.',
        cancelText: 'Cancel',
        confirmText: 'Restore',
        onConfirm: () {},
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(notesRepositoryProvider).restoreNote(_noteId!);

      await _loadNote();

      if (mounted) {
        AppSnackbar.showSuccess(context, message: 'Note restored');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, message: 'Failed to restore note');
      }
    }
  }

  Future<void> _permanentDeleteNote() async {
    if (_isNew || _existingNote == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.trash2,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Delete permanently?',
        message: 'This note will be permanently deleted.',
        cancelText: 'Cancel',
        confirmText: 'Delete permanently',
        confirmColor: Theme.of(context).colorScheme.error,
        onConfirm: () {},
      ),
    );

    if (confirm == true && mounted) {
      final noteId = _noteId!;
      final repo = ref.read(notesRepositoryProvider);
      await _closeThenBurn(
        remove: () => repo.permanentDelete(noteId),
        message: 'Note permanently deleted',
      );
    }
  }

  Widget _buildSharedByBadge(ThemeData theme, String? serverUrl) {
    final sharedBy = _existingNote!.sharedBy!;
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.only(right: dims.xs),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dims.xs, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: AppRadius.lgBorder,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SharedByAvatar(
                sharedBy: sharedBy,
                serverUrl: serverUrl,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Shared by ${sharedBy.name}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinButton(ThemeData theme) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            LucideIcons.pin,
            color: _isPinned
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          if (_isPinned)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onPressed: _isLoaded ? _togglePinned : null,
      tooltip: _isPinned ? 'Unpin Note' : 'Pin Note',
    );
  }

  Widget _buildReadOnlyBanner(ThemeData theme, bool isTrashed) {
    final frozen = !isTrashed && _isFrozen;
    final dims = context.dims;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.editorPadding.left,
        vertical: dims.sm,
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            frozen ? LucideIcons.snowflake : LucideIcons.lock,
            size: AppIconSizes.sm,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: dims.xs),
          Expanded(
            child: Text(
              isTrashed
                  ? 'This note is in trash and cannot be edited. Restore it to make changes.'
                  : frozen
                  ? (_isOwnFrozen
                        ? 'Frozen. It can’t be changed or deleted until you unfreeze it.'
                        : 'Frozen by its owner. It can’t be changed.')
                  : 'You have viewer access. Only the owner can edit this note.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (frozen && _isOwnFrozen)
            TextButton.icon(
              onPressed: () => _setFrozen(false),
              icon: const Icon(LucideIcons.snowflake, size: AppIconSizes.sm),
              label: const Text('Unfreeze'),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorHeader(ThemeData theme) {
    final isReadOnly = _isReadOnly;
    final dims = context.dims;
    final showTags = (_isEditing && !isReadOnly) || _selectedTagIds.isNotEmpty;
    final showAttachments =
        !_isNew && (_existingNote != null || widget.noteId != null);
    final reminder = _existingNote?.reminder;
    final showTitle = !isReadOnly || hasTitleText(_titleController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: EdgeInsets.only(
              left: dims.editorPadding.left,
              right: dims.editorPadding.right,
              top: dims.xs,
            ),
            child: GestureDetector(
              onTap: !isReadOnly
                  ? () {
                      if (!_titleFocusNode.hasFocus) {
                        _titleFocusNode.requestFocus();
                      }
                    }
                  : null,
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                readOnly: isReadOnly,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                ),
                textCapitalization: TextCapitalization.sentences,
                showCursor: _isEditing && !isReadOnly,
                // The keyboard's Next (or Enter) goes straight to the text.
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _editorKey.currentState?.focusStart(),
              ),
            ),
          ),
        if (showTags)
          TagSelector(
            selectedTagIds: _selectedTagIds,
            readOnly: !_isEditing || isReadOnly,
            onTagsChanged: (tagIds) {
              if (!isReadOnly) {
                setState(() => _selectedTagIds = tagIds);
                _onContentChanged();
              }
            },
          ),
        if (reminder != null)
          Padding(
            padding: EdgeInsets.only(
              left: dims.editorPadding.left,
              right: dims.editorPadding.right,
              top: dims.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ReminderChip(
                reminder: reminder,
                onTap: _isActive ? _showReminderPicker : null,
              ),
            ),
          ),
        if (showAttachments)
          GrabImageTextScope(
            onText: _isReadOnly ? null : _appendText,
            child: NoteAttachmentsGallery(
              noteId: widget.noteId ?? _existingNote!.id,
              isOwner: _existingNote?.isOwner ?? false,
              canEdit:
                  (_existingNote?.canEdit ?? false) &&
                  (_existingNote?.isActive ?? false),
              currentUserId: ref.read(activeUserIdProvider),
              hiddenIds: _inlineIds,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serverUrl = ref.watch(serverUrlProvider);
    final isReadOnly = _isReadOnly;
    final isTrashed = _existingNote?.isTrashed ?? false;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAndPop(result);
      },
      child: NoteBackground(
        styleId: _selectedBackground,
        borderRadius: BorderRadius.zero,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: _saveAndPop,
            ),
            actions: [
              if (isTrashed) ...[
                IconButton(
                  icon: const Icon(LucideIcons.rotateCcw),
                  onPressed: _isLoaded && !_isNew ? _restoreNote : null,
                  tooltip: 'Restore note',
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: _isLoaded && !_isNew ? _permanentDeleteNote : null,
                  tooltip: 'Delete permanently',
                ),
              ] else ...[
                if (_existingNote?.sharedBy != null)
                  _buildSharedByBadge(theme, serverUrl),
                _buildPinButton(theme),
                if (!_isNew) ...[
                  IconButton(
                    icon: Icon(
                      _isArchived
                          ? LucideIcons.archiveRestore
                          : LucideIcons.archive,
                    ),
                    onPressed: _isLoaded ? _toggleArchived : null,
                    tooltip: _isArchived ? 'Unarchive note' : 'Archive note',
                  ),
                  if (!_isOwnFrozen)
                    IconButton(
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: _isLoaded ? _deleteNote : null,
                      tooltip: (_existingNote?.isOwner ?? true)
                          ? 'Delete note'
                          : 'Remove note',
                    ),
                ],
                IconButton(
                  icon: const Icon(LucideIcons.moreVertical),
                  tooltip: 'More options',
                  onPressed: _showOptionsSheet,
                ),
              ],
              SizedBox(width: context.dims.xs),
            ],
          ),
          body: Hero(
            tag: 'note_${widget.noteId ?? 'new'}',
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  if (isReadOnly) _buildReadOnlyBanner(theme, isTrashed),
                  Expanded(
                    child: _isLoaded
                        ? RichTextEditor(
                            key: _editorKey,
                            initialContent: _initialContent,
                            hintText: 'Start typing...',
                            showToolbar: !isReadOnly,
                            canEdit: !isReadOnly,
                            onEditingChanged: (_) => _updateEditingState(),
                            onChanged: _onEditorChanged,
                            sortChecklistItems: ref
                                .watch(editorPreferencesControllerProvider)
                                .sortChecklistItems,
                            contentPadding: context.dims.editorPadding,
                            header: _buildEditorHeader(theme),
                            onImageInserted: _onImageInserted,
                            highlightTerm: widget.highlightTerm,
                            highlightOptions: widget.highlightOptions,
                            embedBuilders: _embedBuilders,
                            onTakePicture: isReadOnly
                                ? null
                                : () => _picturesIntoText(fromCamera: true),
                            onPickImages: isReadOnly
                                ? null
                                : () => _picturesIntoText(fromCamera: false),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar widget to display the profile image of the user who shared the note
class _SharedByAvatar extends StatelessWidget {
  final SharedByUser sharedBy;
  final String? serverUrl;
  final double size;

  const _SharedByAvatar({
    required this.sharedBy,
    this.serverUrl,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileImage = sharedBy.profileImage;

    if (profileImage != null && profileImage.isNotEmpty) {
      String imageUrl = profileImage;
      if (!imageUrl.startsWith('http') && serverUrl != null) {
        imageUrl = '$serverUrl$imageUrl';
      }
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallbackAvatar(theme),
          errorWidget: (context, url, error) => _buildFallbackAvatar(theme),
        ),
      );
    }
    return _buildFallbackAvatar(theme);
  }

  Widget _buildFallbackAvatar(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          sharedBy.name.isNotEmpty ? sharedBy.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}
