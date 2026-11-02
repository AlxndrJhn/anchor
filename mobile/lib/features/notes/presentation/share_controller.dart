import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/connectivity_provider.dart';
import '../data/repository/note_shares_repository.dart';
import '../data/repository/users_repository.dart';
import '../domain/note_share.dart';
import '../domain/note_share_link.dart';
import '../domain/note_share_permission.dart';
import '../domain/user_summary.dart';

part 'share_controller.g.dart';

/// Null until the server has answered once.
@Riverpod(keepAlive: true, retry: _noRetry)
class NoteShares extends _$NoteShares {
  @override
  Future<List<NoteShare>?> build(String noteId) async {
    if (!ref.watch(isOnlineProvider)) return state.value;
    return ref.watch(noteSharesRepositoryProvider).getNoteShares(noteId);
  }

  NoteSharesRepository get _repository =>
      ref.read(noteSharesRepositoryProvider);

  void _set(List<NoteShare>? shares) => state = AsyncData(shares);

  Future<void> add(UserSummary user) async {
    final share = await _repository.shareNote(
      noteId,
      user.id,
      NoteSharePermission.viewer,
    );
    _set([...?state.value?.where((s) => s.id != share.id), share]);
  }

  Future<void> setAccess(
    NoteShare share,
    NoteSharePermission permission,
  ) async {
    final before = state.value;
    _set([
      for (final s in before ?? const <NoteShare>[])
        s.id == share.id ? s.copyWith(permission: permission) : s,
    ]);
    try {
      await _repository.updateNoteSharePermission(noteId, share.id, permission);
    } catch (_) {
      _set(before);
      rethrow;
    }
  }

  Future<void> revoke(NoteShare share) async {
    await _repository.revokeShare(noteId, share.id);
    _set([...?state.value?.where((s) => s.id != share.id)]);
  }
}

/// The note's share link; null when it has none.
@Riverpod(retry: _noRetry)
class NoteShareLinkController extends _$NoteShareLinkController {
  @override
  Future<NoteShareLink?> build(String noteId) async {
    // Offline, what it was stays; never asked, it's unknown, not off.
    if (!ref.watch(isOnlineProvider)) {
      if (state.hasValue) return state.value;
      throw StateError('Offline');
    }
    return ref.watch(noteSharesRepositoryProvider).getLink(noteId);
  }

  /// Null [permission] turns the link off.
  Future<NoteShareLink?> setAccess(NoteSharePermission? permission) async {
    final repository = ref.read(noteSharesRepositoryProvider);
    final NoteShareLink? link;
    if (permission == null) {
      await repository.removeLink(noteId);
      link = null;
    } else {
      link = await repository.setLink(noteId, permission);
    }
    if (ref.mounted) state = AsyncData(link);
    return link;
  }
}

@Riverpod(retry: _noRetry)
Future<List<UserSummary>> recentContacts(Ref ref) async {
  if (!ref.watch(isOnlineProvider)) return const [];
  return ref.watch(usersRepositoryProvider).getRecentContacts();
}

const int minSearchLength = 2;

class PeopleSearch {
  const PeopleSearch({this.term = '', this.results, this.isSearching = false});

  /// Empty until [minSearchLength] letters are typed.
  final String term;

  final List<UserSummary>? results;
  final bool isSearching;
}

@riverpod
class PeopleSearchController extends _$PeopleSearchController {
  Timer? _debounce;

  @override
  PeopleSearch build() {
    ref.onDispose(() => _debounce?.cancel());
    return const PeopleSearch();
  }

  void search(String text) {
    final term = text.trim();
    if (term == state.term) return;
    _debounce?.cancel();
    if (term.length < minSearchLength) {
      state = const PeopleSearch();
      return;
    }
    state = PeopleSearch(term: term, results: state.results, isSearching: true);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      List<UserSummary> found;
      try {
        found = await ref.read(usersRepositoryProvider).searchUsers(term);
      } catch (_) {
        found = const [];
      }
      if (!ref.mounted || state.term != term) return;
      state = PeopleSearch(term: term, results: found);
    });
  }
}

Duration? _noRetry(int retryCount, Object error) => null;
