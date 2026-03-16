import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tags_provider.dart';
import 'emoji_data.dart';

/// Inline tag editor row used in the sidebar.
/// Shows [tag label] with edit/delete buttons on hover/long-press.
class TagEditorRow extends ConsumerStatefulWidget {
  const TagEditorRow({super.key, required this.tag, required this.onSelect});

  final Tag tag;
  final VoidCallback onSelect;

  @override
  ConsumerState<TagEditorRow> createState() => _TagEditorRowState();
}

class _TagEditorRowState extends ConsumerState<TagEditorRow> {
  bool _editing = false;
  bool _deleting = false;
  bool _saving = false;
  late String _name;
  late String _emoji;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = widget.tag.name;
    _emoji = widget.tag.emoji;
    _nameCtrl.text = _name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _startEdit() => setState(() {
        _editing = true;
        _nameCtrl.text = widget.tag.name;
        _emoji = widget.tag.emoji;
      });

  Future<void> _saveEdit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(tagsProvider.notifier).update(
            widget.tag.id,
            name: _nameCtrl.text.trim(),
            emoji: _emoji,
          );
      setState(() {
        _editing = false;
        _saving = false;
      });
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    setState(() => _deleting = false, );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text('Delete "${widget.tag.name}"? Notes will keep their content.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(tagsProvider.notifier).delete(widget.tag.id);
    }
  }

  void _showEmojiPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          children: kEmojis
              .map(
                (e) => GestureDetector(
                  onTap: () => Navigator.pop(ctx, e),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) setState(() => _emoji = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showEmojiPicker,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_emoji.isNotEmpty
                    ? _emoji
                    : '🏷️',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saveEdit(),
              ),
            ),
            const SizedBox(width: 4),
            _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.check, size: 18),
                    onPressed: _saveEdit),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _editing = false),
            ),
          ],
        ),
      );
    }

    return ListTile(
      dense: true,
      leading: Text(
        widget.tag.emoji.isNotEmpty ? widget.tag.emoji : '🏷️',
        style: const TextStyle(fontSize: 18),
      ),
      title: Text(widget.tag.name),
      onTap: widget.onSelect,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _startEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }
}
