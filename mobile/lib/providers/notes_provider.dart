import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/notes_repository.dart';
import '../models/note.dart';
import '../models/tag.dart';

class NotesNotifier extends Notifier<List<Note>> {
  final _repo = NotesRepository();

  @override
  List<Note> build() {
    fetchAll();
    return [];
  }

  Future<void> fetchAll() async {
    final notes = await _repo.list();
    state = notes;
  }

  Future<Note?> create({
    required String title,
    required String body,
    required bool isSecret,
    String? credential,
    String? color,
    List<String>? tagIds,
  }) async {
    final note = await _repo.create(
      title: title,
      body: body,
      isSecret: isSecret,
      credential: credential,
      color: color,
      tagIds: tagIds,
    );
    // Pinned notes go first, then sorted by updatedAt desc
    state = [note, ...state];
    return note;
  }

  Future<Note?> update(
    String id, {
    String? title,
    String? body,
    bool? isSecret,
    bool? isPinned,
    String? color,
    String? credential,
    List<String>? tagIds,
  }) async {
    final updated = await _repo.update(
      id,
      title: title,
      body: body,
      isSecret: isSecret,
      isPinned: isPinned,
      color: color,
      credential: credential,
      tagIds: tagIds,
    );
    state = [
      for (final n in state) if (n.id == id) updated else n,
    ];
    return updated;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = state.where((n) => n.id != id).toList();
  }

  Future<Note?> unlock(String id, {required String credential}) async {
    final note = await _repo.unlock(id, credential: credential);
    state = [
      for (final n in state) if (n.id == id) note else n,
    ];
    return note;
  }

  void lockNote(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isLocked: true, clearBody: true) else n,
    ];
  }

  void patchAttachmentCount(String id, int delta) {
    state = [
      for (final n in state)
        if (n.id == id)
          n.copyWith(attachmentCount: (n.attachmentCount ?? 0) + delta)
        else
          n,
    ];
  }

  void patchTagInNotes(Tag updatedTag) {
    state = [
      for (final n in state)
        n.copyWith(
          tags: [
            for (final t in n.tags)
              if (t.id == updatedTag.id) updatedTag else t,
          ],
        ),
    ];
  }

  void removeTagFromNotes(String tagId) {
    state = [
      for (final n in state)
        n.copyWith(tags: n.tags.where((t) => t.id != tagId).toList()),
    ];
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);
