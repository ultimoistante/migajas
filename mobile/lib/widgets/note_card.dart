import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/note.dart';

Color? _noteColor(String? hex) {
  if (hex == null) return null;
  try {
    return Color(int.parse('ff${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accentColor = _noteColor(note.color);
    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: accentColor != null ? const EdgeInsets.all(3) : EdgeInsets.zero,
      child: Card(
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              accentColor != null ? 10 : 12), // inset to stay inside border
        ),
        child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isPinned)
                    Icon(Icons.push_pin, size: 14, color: textColor),
                  if (note.isSecret)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock, size: 14, color: textColor),
                    ),
                ],
              ),
              // Middle section — expands to fill, footer stays at bottom
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Body preview (hidden when locked)
                    if (!note.isLocked &&
                        note.body != null &&
                        note.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Flexible(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: HtmlWidget(
                              _preprocessHtml(note.body!),
                              textStyle: TextStyle(
                                fontSize: 13,
                                color: textColor.withAlpha(180),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    // Locked placeholder
                    if (note.isLocked) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.lock_outline, size: 12, color: textColor),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to unlock',
                            style: TextStyle(
                                fontSize: 12, color: textColor.withAlpha(160)),
                          ),
                        ],
                      ),
                    ],
                    // Tags
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRect(
                        child: LimitedBox(
                          maxHeight: 54,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: note.tags
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.onSurface.withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${t.emoji} ${t.name}',
                                      style: TextStyle(
                                          fontSize: 11, color: textColor),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Footer — always sticky at bottom
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _formatDate(DateTime.tryParse(note.updatedAt) ?? DateTime.now()),
                    style: TextStyle(
                        fontSize: 11,
                        color: textColor.withAlpha(140)),
                  ),
                  if ((note.attachmentCount ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.attach_file, size: 12, color: textColor),
                    Text(
                      '${note.attachmentCount}',
                      style: TextStyle(
                          fontSize: 11, color: textColor.withAlpha(140)),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline,
                        size: 16, color: textColor.withAlpha(160)),
                  ),
                ],
              ),
            ],
          ),
        ),  // Padding
      ),    // InkWell
    ),      // Card
    );      // Container
  }

  static String _preprocessHtml(String html) =>
      // Quill renders task lists as <li data-checked="true/false">
      // flutter_widget_from_html doesn't handle these — convert to ☑/☐ prefixes
      html
          .replaceAll(RegExp(r'<li data-checked="true">'), '<li>☑ ')
          .replaceAll(RegExp(r'<li data-checked="false">'), '<li>☐ ');

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }
}
