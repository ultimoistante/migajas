import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/tags_repository.dart';
import '../models/tag.dart';
import 'notes_provider.dart';

class TagsNotifier extends Notifier<List<Tag>> {
  final _repo = TagsRepository();

  @override
  List<Tag> build() {
    fetchAll();
    return [];
  }

  Future<void> fetchAll() async {
    final tags = await _repo.list();
    state = tags;
  }

  Future<void> create(String name, String emoji) async {
    final tag = await _repo.create(name, emoji);
    state = [...state, tag];
  }

  Future<void> update(String id, {String? name, String? emoji}) async {
    final updatedTag = await _repo.update(id, name: name, emoji: emoji);
    state = [
      for (final t in state) if (t.id == id) updatedTag else t,
    ];
    // Sync updated tag into all loaded notes
    ref.read(notesProvider.notifier).patchTagInNotes(updatedTag);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = state.where((t) => t.id != id).toList();
    // Remove tag from all loaded notes
    ref.read(notesProvider.notifier).removeTagFromNotes(id);
  }
}

final tagsProvider = NotifierProvider<TagsNotifier, List<Tag>>(TagsNotifier.new);

/// Currently selected tag for filtering notes (null = All Notes)
final selectedTagIdProvider = StateProvider<String?>((ref) => null);
