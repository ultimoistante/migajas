import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/attachments_repository.dart';
import '../models/attachment.dart';
import '../models/note.dart';
import '../models/tag.dart';
import '../providers/notes_provider.dart';
import '../providers/tags_provider.dart';
import 'attachment_panel.dart';
import 'color_picker_row.dart';
import 'rich_editor.dart';
import 'unlock_dialog.dart';

/// Opens the note sheet as a full-screen dialog.
/// Pass [note] to edit an existing note, or null to create a new one.
Future<void> showNoteSheet(BuildContext context, {Note? note}) {
  return showDialog(
    context: context,
    useSafeArea: true,
    barrierDismissible: false,
    builder: (ctx) => Dialog.fullscreen(child: NoteSheet(note: note)),
  );
}

class NoteSheet extends ConsumerStatefulWidget {
  const NoteSheet({super.key, this.note});
  final Note? note;

  @override
  ConsumerState<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<NoteSheet> {
  final _attRepo = AttachmentsRepository();

  bool get _isNew => widget.note == null;

  // Form state
  late TextEditingController _titleCtrl;
  String _body = '';
  bool _isSecret = false;
  bool _isPinned = false;
  String? _color;
  List<String> _selectedTagIds = [];
  List<Attachment> _attachments = [];

  // UI state
  bool _saving = false;
  bool _loadingAtts = false;
  bool _unlocking = false;
  bool _unlocked = false;
  String? _error;
  String? _currentNoteId; // set after auto-save
  bool _showAttachments = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _body = n?.body ?? '';
    _isSecret = n?.isSecret ?? false;
    _isPinned = n?.isPinned ?? false;
    _color = n?.color;
    _selectedTagIds = n?.tags.map((t) => t.id).toList() ?? [];
    _currentNoteId = n?.id;

    if (n != null && !n.isLocked) {
      _loadAttachments(n.id);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAttachments(String noteId) async {
    setState(() => _loadingAtts = true);
    try {
      final atts = await _attRepo.list(noteId);
      setState(() => _attachments = atts);
    } catch (_) {}
    setState(() => _loadingAtts = false);
  }

  Future<void> _unlock() async {
    final credential = await showUnlockDialog(context, widget.note!);
    if (credential == null) return;
    setState(() => _unlocking = true);
    try {
      final unlocked = await ref
          .read(notesProvider.notifier)
          .unlock(widget.note!.id, credential: credential);
      if (unlocked != null) {
        setState(() {
          _body = unlocked.body ?? '';
          _unlocked = true;
          _unlocking = false;
        });
        await _loadAttachments(widget.note!.id);
      }
    } catch (_) {
      setState(() {
        _unlocking = false;
        _error = 'Wrong PIN / password.';
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_currentNoteId != null) {
        // Update (handles: edit existing OR auto-saved note with attachments)
        await ref.read(notesProvider.notifier).update(
              _currentNoteId!,
              title: _titleCtrl.text.trim(),
              body: _body,
              isSecret: _isSecret,
              isPinned: _isPinned,
              color: _color,
              tagIds: _selectedTagIds,
            );
      } else {
        final created = await ref.read(notesProvider.notifier).create(
              title: _titleCtrl.text.trim(),
              body: _body,
              isSecret: _isSecret,
              color: _color,
              tagIds: _selectedTagIds,
            );
        _currentNoteId = created?.id;
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  /// Auto-save a new note so attachments can be uploaded against a real ID.
  Future<void> _ensureNoteSaved() async {
    if (_currentNoteId != null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      _titleCtrl.text = 'Untitled ${DateTime.now().millisecondsSinceEpoch}';
    }
    final created = await ref.read(notesProvider.notifier).create(
          title: _titleCtrl.text.trim(),
          body: _body,
          isSecret: _isSecret,
          tagIds: _selectedTagIds,
        );
    _currentNoteId = created?.id;
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider);
    final isLocked = widget.note?.isLocked == true && !_unlocked;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isNew ? 'New note' : 'Edit note'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: isLocked
          ? _buildLockedView()
          : _buildEditView(tags),
    );
  }

  Widget _buildLockedView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 64),
          const SizedBox(height: 16),
          Text(
            widget.note?.title ?? '',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _unlocking
              ? const CircularProgressIndicator()
              : FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock'),
                ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(
                color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildEditView(List<Tag> tags) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
          const Divider(),

          // Rich editor
          Container(
            constraints: const BoxConstraints(minHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RichEditor(
              initialHtml: _body,
              onChanged: (html) => _body = html,
            ),
          ),

          const SizedBox(height: 12),

          // Secret toggle
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Secret note'),
            value: _isSecret,
            onChanged: (v) => setState(() => _isSecret = v),
          ),

          // Color picker
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ColorPickerRow(
                value: _color,
                onChanged: (c) => setState(() => _color = c)),
          ),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Tags',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) {
                final selected = _selectedTagIds.contains(t.id);
                return FilterChip(
                  label: Text('${t.emoji} ${t.name}'),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedTagIds = [..._selectedTagIds, t.id];
                      } else {
                        _selectedTagIds =
                            _selectedTagIds.where((id) => id != t.id).toList();
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 4),

          // Attachments toggle
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              if (!_showAttachments) {
                await _ensureNoteSaved();
                setState(() => _showAttachments = true);
              } else {
                setState(() => _showAttachments = !_showAttachments);
              }
            },
            icon: const Icon(Icons.attach_file),
            label: Text(
              'Attachments${_attachments.isNotEmpty ? ' (${_attachments.length})' : ''}',
            ),
          ),

          if (_showAttachments)
            _loadingAtts
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()))
                : AttachmentPanel(
                    note: widget.note ??
                        Note(
                          id: _currentNoteId ?? '',
                          userId: '',
                          title: _titleCtrl.text,
                          isSecret: _isSecret,
                          isLocked: false,
                          isPinned: false,
                          tags: const [],
                          createdAt: '',
                          updatedAt: '',
                        ),
                    attachments: _attachments,
                    onChanged: (list) => setState(() => _attachments = list),
                  ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
