import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import 'notes_provider.dart';
import 'tags_provider.dart';

/// A simple text search filter
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Derived: filtered + sorted notes list
final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesProvider);
  final selectedTagId = ref.watch(selectedTagIdProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  var filtered = notes;

  // Filter by selected tag
  if (selectedTagId != null) {
    filtered = filtered
        .where((n) => n.tags.any((t) => t.id == selectedTagId))
        .toList();
  }

  // Filter by search text (title match)
  if (query.isNotEmpty) {
    filtered = filtered
        .where((n) => n.title.toLowerCase().contains(query))
        .toList();
  }

  // Pinned first, then by updatedAt desc
  filtered.sort((a, b) {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });

  return filtered;
});
