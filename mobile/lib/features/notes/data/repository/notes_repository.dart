import 'package:anchor/core/widgets/editor/append_text.dart';
import 'package:anchor/core/widgets/editor/checklist_lines.dart';
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/sync_requester.dart';
import '../../../tags/data/repository/tags_repository.dart';
import '../../domain/note.dart' as domain;
import '../../domain/note_attachment.dart' as domain;
import '../../domain/note_revision.dart';
import '../local/reminder_slots.dart';
import 'note_attachments_repository.dart';
import 'note_revisions_store.dart';

part 'notes_repository.g.dart';

@riverpod
NotesRepository notesRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final tagsRepo = ref.watch(tagsRepositoryProvider);
  final attachmentsRepo = ref.watch(noteAttachmentsRepositoryProvider);
  final revisions = ref.watch(noteRevisionsStoreProvider);
  return NotesRepository(db, tagsRepo, attachmentsRepo, revisions);
}

/// Notes on the device. Nothing here talks to the server.
class NotesRepository {
  final AppDatabase _db;
  final TagsRepository _tagsRepo;
  final NoteAttachmentsRepository _attachmentsRepo;
  final NoteRevisionsStore _revisions;

  NotesRepository(
    this._db,
    this._tagsRepo,
    this._attachmentsRepo,
    this._revisions,
  );

  drift.Expression<int> get _nextRev =>
      _db.notes.localRev + const drift.Constant(1);

  // Watch only active notes
  // Uses left outer joins to fetch notes, their tags, and image attachment paths
  Stream<List<domain.Note>> watchNotes({String? tagId}) {
    final query = _db.select(_db.notes).join([
      drift.leftOuterJoin(
        _db.noteTags,
        _db.noteTags.noteId.equalsExp(_db.notes.id),
      ),
      drift.leftOuterJoin(
        _db.noteAttachments,
        _db.noteAttachments.noteId.equalsExp(_db.notes.id) &
            _db.noteAttachments.type.equals('image') &
            _db.noteAttachments.syncStatus.isNotValue(
              domain.AttachmentSyncStatus.pendingDelete.dbValue,
            ),
      ),
    ]);

    // Apply filters - exclude archived notes from main list
    query.where(_db.notes.state.equals('active'));
    query.where(_db.notes.isArchived.equals(false));

    if (tagId != null) {
      query.where(
        _db.notes.id.isInQuery(
          _db.selectOnly(_db.noteTags)
            ..addColumns([_db.noteTags.noteId])
            ..where(_db.noteTags.tagId.equals(tagId)),
        ),
      );
    }

    query.orderBy([
      drift.OrderingTerm(
        expression: _db.notes.isPinned,
        mode: drift.OrderingMode.desc,
      ),
      drift.OrderingTerm(
        expression: _db.notes.updatedAt,
        mode: drift.OrderingMode.desc,
      ),
      drift.OrderingTerm(
        expression: _db.notes.id,
        mode: drift.OrderingMode.desc,
      ),
      drift.OrderingTerm(
        expression: _db.noteAttachments.position,
        mode: drift.OrderingMode.asc,
      ),
    ]);

    // Watch the query - emits when notes, noteTags, or noteAttachments change
    return query.watch().map((rows) {
      // Group rows by note ID to handle one-to-many relationships
      final noteMap = <String, domain.Note>{};
      // Track up to 4 image attachment previews per note
      final imagePreviewsMap = <String, List<domain.NoteImagePreview>>{};
      // The text read from each picture, by attachment (tags repeat rows).
      final pictureTexts = <String, Map<String, String>>{};

      for (final row in rows) {
        final note = row.readTable(_db.notes);
        final tagRow = row.readTableOrNull(_db.noteTags);
        final attachmentRow = row.readTableOrNull(_db.noteAttachments);

        if (!noteMap.containsKey(note.id)) {
          noteMap[note.id] = _mapToDomain(note, []);
          imagePreviewsMap[note.id] = [];
        }

        if (tagRow?.tagId != null) {
          final currentNote = noteMap[note.id]!;
          if (!currentNote.tagIds.contains(tagRow!.tagId)) {
            noteMap[note.id] = currentNote.copyWith(
              tagIds: [...currentNote.tagIds, tagRow.tagId],
            );
          }
        }

        if (attachmentRow != null) {
          final previews = imagePreviewsMap[note.id]!;
          final attachmentId =
              attachmentRow.serverAttachmentId ?? attachmentRow.id;
          final pictureText = attachmentRow.pictureText;
          if (pictureText != null && pictureText.isNotEmpty) {
            (pictureTexts[note.id] ??= {})[attachmentId] = pictureText;
          }
          if (previews.length < 4 &&
              !previews.any((p) => p.attachmentId == attachmentId)) {
            previews.add(
              domain.NoteImagePreview(
                attachmentId: attachmentId,
                noteId: note.id,
                filename: attachmentRow.originalFilename,
                localPath: attachmentRow.localPath,
              ),
            );
          }
        }
      }

      return noteMap.entries.map((entry) {
        return entry.value.copyWith(
          imagePreviewData: imagePreviewsMap[entry.key] ?? [],
          pictureText: pictureTexts[entry.key]?.values.join('\n\n') ?? '',
        );
      }).toList();
    });
  }

  // Watch trashed notes for Trash screen
  // Only show notes owned by the current user (not shared notes that were trashed by others)
  Stream<List<domain.Note>> watchTrashedNotes() async* {
    final query =
        _db.select(_db.notes).join([
            drift.leftOuterJoin(
              _db.noteTags,
              _db.noteTags.noteId.equalsExp(_db.notes.id),
            ),
            drift.leftOuterJoin(
              _db.noteAttachments,
              _db.noteAttachments.noteId.equalsExp(_db.notes.id) &
                  _db.noteAttachments.type.equals('image') &
                  _db.noteAttachments.syncStatus.isNotValue(
                    domain.AttachmentSyncStatus.pendingDelete.dbValue,
                  ),
            ),
          ])
          ..where(_db.notes.state.equals('trashed'))
          ..orderBy([
            drift.OrderingTerm(
              expression: _db.notes.updatedAt,
              mode: drift.OrderingMode.desc,
            ),
            drift.OrderingTerm(
              expression: _db.notes.id,
              mode: drift.OrderingMode.desc,
            ),
            drift.OrderingTerm(
              expression: _db.noteAttachments.position,
              mode: drift.OrderingMode.asc,
            ),
          ]);

    await for (final rows in query.watch()) {
      final noteMap = <String, domain.Note>{};
      final imagePreviewsMap = <String, List<domain.NoteImagePreview>>{};
      // The text read from each picture, by attachment (tags repeat rows).
      final pictureTexts = <String, Map<String, String>>{};

      for (final row in rows) {
        final note = row.readTable(_db.notes);
        final tagId = row.readTableOrNull(_db.noteTags)?.tagId;
        final attachmentRow = row.readTableOrNull(_db.noteAttachments);

        // Skip shared notes that are trashed (only show owned notes)
        if (note.permission != 'owner') {
          continue;
        }

        if (!noteMap.containsKey(note.id)) {
          noteMap[note.id] = _mapToDomain(note, []);
          imagePreviewsMap[note.id] = [];
        }

        if (tagId != null) {
          final currentNote = noteMap[note.id]!;
          if (!currentNote.tagIds.contains(tagId)) {
            noteMap[note.id] = currentNote.copyWith(
              tagIds: [...currentNote.tagIds, tagId],
            );
          }
        }

        if (attachmentRow != null) {
          final previews = imagePreviewsMap[note.id]!;
          final attachmentId =
              attachmentRow.serverAttachmentId ?? attachmentRow.id;
          final pictureText = attachmentRow.pictureText;
          if (pictureText != null && pictureText.isNotEmpty) {
            (pictureTexts[note.id] ??= {})[attachmentId] = pictureText;
          }
          if (previews.length < 4 &&
              !previews.any((p) => p.attachmentId == attachmentId)) {
            previews.add(
              domain.NoteImagePreview(
                attachmentId: attachmentId,
                noteId: note.id,
                filename: attachmentRow.originalFilename,
                localPath: attachmentRow.localPath,
              ),
            );
          }
        }
      }

      yield noteMap.entries
          .map(
            (e) => e.value.copyWith(
              imagePreviewData: imagePreviewsMap[e.key] ?? [],
              pictureText: pictureTexts[e.key]?.values.join('\n\n') ?? '',
            ),
          )
          .toList();
    }
  }

  // Watch archived notes for Archive screen
  Stream<List<domain.Note>> watchArchivedNotes() {
    final query =
        _db.select(_db.notes).join([
            drift.leftOuterJoin(
              _db.noteTags,
              _db.noteTags.noteId.equalsExp(_db.notes.id),
            ),
            drift.leftOuterJoin(
              _db.noteAttachments,
              _db.noteAttachments.noteId.equalsExp(_db.notes.id) &
                  _db.noteAttachments.type.equals('image') &
                  _db.noteAttachments.syncStatus.isNotValue(
                    domain.AttachmentSyncStatus.pendingDelete.dbValue,
                  ),
            ),
          ])
          ..where(_db.notes.state.equals('active'))
          ..where(_db.notes.isArchived.equals(true))
          ..orderBy([
            drift.OrderingTerm(
              expression: _db.notes.updatedAt,
              mode: drift.OrderingMode.desc,
            ),
            drift.OrderingTerm(
              expression: _db.notes.id,
              mode: drift.OrderingMode.desc,
            ),
            drift.OrderingTerm(
              expression: _db.noteAttachments.position,
              mode: drift.OrderingMode.asc,
            ),
          ]);

    return query.watch().map((rows) {
      final noteMap = <String, domain.Note>{};
      final imagePreviewsMap = <String, List<domain.NoteImagePreview>>{};
      // The text read from each picture, by attachment (tags repeat rows).
      final pictureTexts = <String, Map<String, String>>{};

      for (final row in rows) {
        final note = row.readTable(_db.notes);
        final tagId = row.readTableOrNull(_db.noteTags)?.tagId;
        final attachmentRow = row.readTableOrNull(_db.noteAttachments);

        if (!noteMap.containsKey(note.id)) {
          noteMap[note.id] = _mapToDomain(note, []);
          imagePreviewsMap[note.id] = [];
        }

        if (tagId != null) {
          final currentNote = noteMap[note.id]!;
          if (!currentNote.tagIds.contains(tagId)) {
            noteMap[note.id] = currentNote.copyWith(
              tagIds: [...currentNote.tagIds, tagId],
            );
          }
        }

        if (attachmentRow != null) {
          final previews = imagePreviewsMap[note.id]!;
          final attachmentId =
              attachmentRow.serverAttachmentId ?? attachmentRow.id;
          final pictureText = attachmentRow.pictureText;
          if (pictureText != null && pictureText.isNotEmpty) {
            (pictureTexts[note.id] ??= {})[attachmentId] = pictureText;
          }
          if (previews.length < 4 &&
              !previews.any((p) => p.attachmentId == attachmentId)) {
            previews.add(
              domain.NoteImagePreview(
                attachmentId: attachmentId,
                noteId: note.id,
                filename: attachmentRow.originalFilename,
                localPath: attachmentRow.localPath,
              ),
            );
          }
        }
      }

      return noteMap.entries
          .map(
            (e) => e.value.copyWith(
              imagePreviewData: imagePreviewsMap[e.key] ?? [],
              pictureText: pictureTexts[e.key]?.values.join('\n\n') ?? '',
            ),
          )
          .toList();
    });
  }

  Future<domain.Note?> getNote(String id) async {
    final row = await _noteRow(id);
    if (row == null) return null;
    final tagIds = await _tagsRepo.getTagIdsForNote(id);
    return _mapToDomain(row, tagIds);
  }

  /// One note and its tags, re-emitted whenever either changes.
  Stream<domain.Note?> watchNote(String id) {
    final query = _db.select(_db.notes).join([
      drift.leftOuterJoin(
        _db.noteTags,
        _db.noteTags.noteId.equalsExp(_db.notes.id),
      ),
    ])..where(_db.notes.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) return null;

      final tagIds = <String>[];
      for (final row in rows) {
        final tagId = row.readTableOrNull(_db.noteTags)?.tagId;
        if (tagId != null && !tagIds.contains(tagId)) {
          tagIds.add(tagId);
        }
      }

      return _mapToDomain(rows.first.readTable(_db.notes), tagIds);
    });
  }

  Future<void> createNote(domain.Note note) async {
    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              id: note.id,
              title: note.title,
              content: drift.Value(note.content),
              isPinned: drift.Value(note.isPinned),
              isArchived: drift.Value(note.isArchived),
              background: drift.Value(note.background),
              state: drift.Value(domain.NoteState.active.name),
              updatedAt: drift.Value(DateTime.now().toUtc()),
              createdAt: drift.Value(DateTime.now().toUtc()),
              isSynced: const drift.Value(false),
              localRev: const drift.Value(1),
              // The server creates notes unpinned, so a pin has to follow.
              isPinSynced: drift.Value(!note.isPinned),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
      await _tagsRepo.setTagsForNote(note.id, note.tagIds);
    });

    AppLogger.instance.info(
      'Notes',
      'createNote id=${note.id} title.len=${note.title.length} '
          'content.len=${note.content?.length ?? 0} tags=${note.tagIds.length}',
    );

    scheduleAppSync(trigger: 'NotesRepo.createNote');
  }

  Future<void> updateNote(domain.Note note) async {
    await _db.transaction(() async {
      final prior = await _noteRow(note.id);
      if (prior == null) return;

      if (prior.title != note.title || prior.content != note.content) {
        await _revisions.record(prior);
      }
      final noteChanged =
          prior.title != note.title ||
          prior.content != note.content ||
          prior.background != note.background ||
          prior.state != note.state.name;

      await (_db.update(
        _db.notes,
      )..where((tbl) => tbl.id.equals(note.id))).write(
        NotesCompanion(
          title: drift.Value(note.title),
          content: drift.Value(note.content),
          isPinned: drift.Value(note.isPinned),
          isArchived: drift.Value(note.isArchived),
          background: drift.Value(note.background),
          state: drift.Value(note.state.name),
          updatedAt: noteChanged
              ? drift.Value(DateTime.now().toUtc())
              : const drift.Value.absent(),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
          isPinSynced: prior.isPinned == note.isPinned
              ? const drift.Value.absent()
              : const drift.Value(false),
        ),
      );
      await _tagsRepo.setTagsForNote(note.id, note.tagIds);
    });

    AppLogger.instance.info(
      'Notes',
      'updateNote id=${note.id} title.len=${note.title.length} '
          'content.len=${note.content?.length ?? 0} tags=${note.tagIds.length}',
    );

    scheduleAppSync(trigger: 'NotesRepo.updateNote');
  }

  /// Ticks or unticks the checklist item on [lineIndex] without opening the
  /// note, re-sorting its list when [sort] is on.
  Future<void> toggleChecklistItem(
    String noteId,
    int lineIndex, {
    required bool sort,
  }) async {
    final note = await getNote(noteId);
    if (note == null) return;
    final content = toggleChecklistItemContent(
      note.content,
      lineIndex,
      sort: sort,
    );
    if (content == null) return;
    await updateNote(note.copyWith(content: content));
  }

  /// Adds lines of text at the end of a note that isn't open ("Grab image
  /// text" on a picture opened from the list).
  Future<void> appendText(String noteId, String text) async {
    final note = await getNote(noteId);
    if (note == null || text.trim().isEmpty) return;
    await updateNote(
      note.copyWith(content: appendTextContent(note.content, text)),
    );
  }

  /// Puts an earlier version back on the note. What it says now is kept as a
  /// version of its own.
  Future<void> restoreVersion(String noteId, NoteRevision revision) async {
    await _db.transaction(() async {
      final prior = await _noteRow(noteId);
      if (prior == null) return;
      if (prior.title == revision.title && prior.content == revision.content) {
        return;
      }

      await _revisions.record(prior, cause: RevisionCause.restore);
      await (_db.update(
        _db.notes,
      )..where((tbl) => tbl.id.equals(noteId))).write(
        NotesCompanion(
          title: drift.Value(revision.title),
          content: drift.Value(revision.content),
          updatedAt: drift.Value(DateTime.now().toUtc()),
          isSynced: const drift.Value(false),
          localRev: drift.Value(prior.localRev + 1),
        ),
      );
    });

    AppLogger.instance.info(
      'Notes',
      'restoreVersion id=$noteId revision=${revision.id}',
    );

    scheduleAppSync(trigger: 'NotesRepo.restoreVersion');
  }

  // Soft delete - moves note to trash
  Future<void> deleteNote(String id) async {
    await _trashOrRemove([id]);
    scheduleAppSync(trigger: 'NotesRepo.deleteNote');
  }

  // Restore from trash
  Future<void> restoreNote(String id) async {
    await _writeState(ids: [id], state: 'active');
    scheduleAppSync(trigger: 'NotesRepo.restoreNote');
  }

  /// Sets or clears the reminder on a note, leaving the note itself alone.
  Future<void> setReminder(String noteId, domain.NoteReminder? reminder) async {
    await _db.transaction(() async {
      final prior = await _noteRow(noteId);
      if (prior == null) return;

      final slot = reminder == null
          ? null
          : await ensureReminderSlot(_db, noteId);

      await (_db.update(
        _db.notes,
      )..where((tbl) => tbl.id.equals(noteId))).write(
        NotesCompanion(
          reminderAt: drift.Value(reminder?.remindAt),
          reminderRecurrence: drift.Value(reminder?.recurrence.name),
          isReminderSynced: const drift.Value(false),
          reminderSlot: slot == null
              ? const drift.Value.absent()
              : drift.Value(slot),
        ),
      );
    });

    AppLogger.instance.info(
      'Notes',
      'setReminder id=$noteId at=${reminder?.remindAt ?? 'none'} '
          'repeat=${reminder?.recurrence.name ?? 'none'}',
    );
    scheduleAppSync(trigger: 'NotesRepo.setReminder');
  }

  // Archive a note
  Future<void> archiveNote(String id) async {
    await _writeArchived(ids: [id], isArchived: true);
    scheduleAppSync(trigger: 'NotesRepo.archiveNote');
  }

  // Unarchive a note
  Future<void> unarchiveNote(String id) async {
    await _writeArchived(ids: [id], isArchived: false);
    scheduleAppSync(trigger: 'NotesRepo.unarchiveNote');
  }

  // Bulk delete notes
  Future<int> bulkDeleteNotes(List<String> ids) async {
    if (ids.isEmpty) return 0;
    await _trashOrRemove(ids);
    scheduleAppSync(trigger: 'NotesRepo.bulkDeleteNotes');
    return ids.length;
  }

  // Bulk archive notes
  Future<int> bulkArchiveNotes(List<String> ids) async {
    if (ids.isEmpty) return 0;
    await _writeArchived(ids: ids, isArchived: true);
    scheduleAppSync(trigger: 'NotesRepo.bulkArchiveNotes');
    return ids.length;
  }

  // Pins sync on their own, so the note itself is left alone.
  Future<int> bulkSetPinned(List<String> ids, bool isPinned) async {
    if (ids.isEmpty) return 0;

    await (_db.update(_db.notes)..where((tbl) => tbl.id.isIn(ids))).write(
      NotesCompanion(
        isPinned: drift.Value(isPinned),
        isPinSynced: const drift.Value(false),
      ),
    );

    scheduleAppSync(trigger: 'NotesRepo.bulkSetPinned');
    return ids.length;
  }

  /// Puts a note where it was dragged among the notes; it stays there until it
  /// is next edited, and goes up with the note.
  Future<void> setPosition(String noteId, double position) async {
    await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(noteId))).write(
      NotesCompanion.custom(
        position: drift.Constant(position),
        positionedAt: drift.Constant(DateTime.now().toUtc()),
        isSynced: const drift.Constant(false),
        localRev: _nextRev,
      ),
    );
    scheduleAppSync(trigger: 'NotesRepo.setPosition');
  }

  /// Gives every note the same colour or pattern (null for none). Only notes
  /// this person can edit change; the count says how many did.
  Future<int> bulkSetBackground(List<String> ids, String? background) async {
    if (ids.isEmpty) return 0;
    final editable =
        await (_db.select(_db.notes)
              ..where((tbl) => tbl.id.isIn(ids))
              ..where((tbl) => tbl.permission.isIn(const ['owner', 'editor'])))
            .map((row) => row.id)
            .get();
    if (editable.isEmpty) return 0;

    await (_db.update(_db.notes)..where((tbl) => tbl.id.isIn(editable))).write(
      NotesCompanion.custom(
        background: drift.Constant(background),
        updatedAt: drift.Constant(DateTime.now().toUtc()),
        isSynced: const drift.Constant(false),
        localRev: _nextRev,
      ),
    );

    scheduleAppSync(trigger: 'NotesRepo.bulkSetBackground');
    return editable.length;
  }

  // Bulk add tags to notes (merge — each note keeps its existing tags)
  Future<int> bulkAddTags(List<String> ids, List<String> tagIds) async {
    if (ids.isEmpty || tagIds.isEmpty) return 0;

    await _db.transaction(() async {
      // insertOrReplace on the (noteId, tagId) key makes this idempotent.
      await _db.batch((batch) {
        for (final noteId in ids) {
          batch.insertAll(
            _db.noteTags,
            tagIds
                .map(
                  (tagId) => NoteTagsCompanion(
                    noteId: drift.Value(noteId),
                    tagId: drift.Value(tagId),
                  ),
                )
                .toList(),
            mode: drift.InsertMode.insertOrReplace,
          );
        }
      });

      await _markUnsynced(ids);
    });

    scheduleAppSync(trigger: 'NotesRepo.bulkAddTags');
    return ids.length;
  }

  /// Replaces this user's tags on a note, leaving the note itself alone.
  Future<void> setNoteTags(String noteId, List<String> tagIds) async {
    await _db.transaction(() async {
      await _tagsRepo.setTagsForNote(noteId, tagIds);
      await _markUnsynced([noteId]);
    });
    scheduleAppSync(trigger: 'NotesRepo.setNoteTags');
  }

  Future<void> _markUnsynced(List<String> ids) async {
    await (_db.update(_db.notes)..where((tbl) => tbl.id.isIn(ids))).write(
      NotesCompanion.custom(
        isSynced: const drift.Constant(false),
        localRev: _nextRev,
      ),
    );
  }

  // Marked deleted here; the row goes once the server has been told.
  Future<void> permanentDelete(String id) async {
    await _attachmentsRepo.deleteAllLocalForNote(id);
    await _revisions.deleteForNote(id);
    await _writeState(ids: [id], state: 'deleted');
    await (_db.delete(
      _db.noteTags,
    )..where((tbl) => tbl.noteId.equals(id))).go();

    scheduleAppSync(trigger: 'NotesRepo.permanentDelete');
  }

  /// Shared notes are marked deleted, which leaves the share.
  Future<void> _trashOrRemove(List<String> ids) async {
    final shared =
        await (_db.select(_db.notes)..where(
              (tbl) => tbl.id.isIn(ids) & tbl.permission.equals('owner').not(),
            ))
            .map((row) => row.id)
            .get();
    final owned = ids.where((id) => !shared.contains(id)).toList();
    if (owned.isNotEmpty) await _writeState(ids: owned, state: 'trashed');
    if (shared.isNotEmpty) await _writeState(ids: shared, state: 'deleted');
  }

  Future<void> _writeState({
    required List<String> ids,
    required String state,
  }) async {
    await (_db.update(_db.notes)..where((tbl) => tbl.id.isIn(ids))).write(
      NotesCompanion.custom(
        state: drift.Constant(state),
        updatedAt: drift.Variable(DateTime.now().toUtc()),
        isSynced: const drift.Constant(false),
        localRev: _nextRev,
      ),
    );
  }

  Future<void> _writeArchived({
    required List<String> ids,
    required bool isArchived,
  }) async {
    await (_db.update(_db.notes)..where((tbl) => tbl.id.isIn(ids))).write(
      NotesCompanion.custom(
        isArchived: drift.Constant(isArchived),
        isSynced: const drift.Constant(false),
        localRev: _nextRev,
      ),
    );
  }

  Future<Note?> _noteRow(String id) => (_db.select(
    _db.notes,
  )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  domain.Note _mapToDomain(Note row, List<String> tagIds) {
    return domain.Note(
      id: row.id,
      title: row.title,
      content: row.content,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
      background: row.background,
      state: domain.NoteState.fromString(row.state),
      updatedAt: row.updatedAt,
      createdAt: row.createdAt,
      position: row.position,
      positionedAt: row.positionedAt,
      tagIds: tagIds,
      permission: domain.NotePermission.fromString(row.permission),
      shareIds: row.shareIds?.isNotEmpty == true
          ? List<String>.from(jsonDecode(row.shareIds!))
          : [],
      sharedBy: row.sharedById != null
          ? domain.SharedByUser(
              id: row.sharedById!,
              name: row.sharedByName ?? '',
              email: row.sharedByEmail ?? '',
              profileImage: row.sharedByProfileImage,
            )
          : null,
      isSynced: row.isSynced,
      reminderSlot: row.reminderSlot,
      reminder: row.reminderAt == null
          ? null
          : domain.NoteReminder(
              remindAt: row.reminderAt!,
              recurrence: domain.ReminderRecurrence.fromString(
                row.reminderRecurrence,
              ),
              version: row.reminderVersion ?? 0,
            ),
    );
  }
}
