import 'package:flutter/material.dart';
import '../models/note.dart';

/// Shows a confirmation dialog before deleting a note.
/// Returns true when the user taps Delete, false/null otherwise.
Future<bool?> showDeleteNoteDialog(BuildContext context, Note note) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteNoteDialog(note: note),
  );
}

class _DeleteNoteDialog extends StatelessWidget {
  const _DeleteNoteDialog({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete note?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note title row with icons
          Row(
            children: [
              if (note.isPinned)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: Icon(Icons.push_pin, size: 16),
                ),
              if (note.isSecret)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 4),
                  child: Icon(Icons.lock, size: 16),
                ),
              Flexible(
                child: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Tags
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: note.tags
                  .map(
                    (t) => Chip(
                      label: Text('${t.emoji} ${t.name}'),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          // Attachment warning
          if ((note.attachmentCount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: cs.error),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${note.attachmentCount} attachment${note.attachmentCount == 1 ? '' : 's'} will also be deleted.',
                    style: TextStyle(color: cs.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'This action cannot be undone.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
