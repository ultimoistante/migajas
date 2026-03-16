import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/note.dart';
import '../models/tag.dart';
import '../providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/tags_provider.dart';
import '../providers/filters_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/note_sheet.dart';
import '../widgets/tag_editor.dart';
import '../widgets/delete_note_dialog.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeProvider);
    final tags = ref.watch(tagsProvider);
    final filteredNotes = ref.watch(filteredNotesProvider);
    final selectedTagId = ref.watch(selectedTagIdProvider);
    final isWide = MediaQuery.of(context).size.width >= 600;

    final sidebar = _Sidebar(
      user: user?.username ?? '',
      tags: tags,
      selectedTagId: selectedTagId,
      onTagSelected: (id) {
          ref.read(selectedTagIdProvider.notifier).state = id;
          if (!isWide) Navigator.of(context).pop();
        },
      onSettings: () => context.push('/settings'),
      onAdmin: user?.isAdmin == true ? () => context.push('/admin') : null,
      onLogout: () => ref.read(authProvider.notifier).logout(),
      themeMode: themeMode,
      onToggleTheme: () => ref.read(themeProvider.notifier).toggle(),
    );

    final notesGrid = _NotesGrid(
      notes: filteredNotes,
      onTap: (note) => showNoteSheet(context, note: note),
      onDelete: (note) async {
        final confirmed = await showDeleteNoteDialog(context, note);
        if (confirmed == true) {
          await ref.read(notesProvider.notifier).delete(note.id);
        }
      },
    );

    final fab = FloatingActionButton(
      onPressed: () => showNoteSheet(context),
      child: const Icon(Icons.add),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 260, child: sidebar),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scaffold(
                appBar: _buildSearchBar(context),
                body: notesGrid,
                floatingActionButton: fab,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildSearchBar(context),
      drawer: Drawer(child: sidebar),
      body: notesGrid,
      floatingActionButton: fab,
    );
  }

  AppBar _buildSearchBar(BuildContext context) {
    return AppBar(
      title: TextField(
        controller: _searchCtrl,
        onChanged: (v) =>
            ref.read(searchQueryProvider.notifier).state = v,
        decoration: const InputDecoration(
          hintText: 'Search notes…',
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search),
        ),
      ),
      actions: [
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchCtrl.clear();
              ref.read(searchQueryProvider.notifier).state = '';
            },
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({
    required this.user,
    required this.tags,
    required this.selectedTagId,
    required this.onTagSelected,
    required this.onSettings,
    this.onAdmin,
    required this.onLogout,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final String user;
  final List<Tag> tags;
  final String? selectedTagId;
  final ValueChanged<String?> onTagSelected;
  final VoidCallback onSettings;
  final VoidCallback? onAdmin;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  bool _showNewTagForm = false;
  final _newTagNameCtrl = TextEditingController();
  String _newTagEmoji = '';
  bool _savingTag = false;

  @override
  void dispose() {
    _newTagNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header area
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.notes, size: 28),
                const SizedBox(width: 8),
                Text('migajas',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: Icon(widget.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode),
                  onPressed: widget.onToggleTheme,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Tag filter list
        Expanded(
          child: ListView(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.notes, size: 18),
                title: const Text('All Notes'),
                selected: widget.selectedTagId == null,
                onTap: () => widget.onTagSelected(null),
              ),
              const Divider(),
              ...widget.tags.map((tag) => TagEditorRow(
                    tag: tag,
                    onSelect: () => widget.onTagSelected(tag.id),
                  )),
              // New tag form
              if (_showNewTagForm)
                _NewTagForm(
                  nameCtrl: _newTagNameCtrl,
                  emoji: _newTagEmoji,
                  saving: _savingTag,
                  onEmojiTap: () async {
                    // Simple bottom-sheet emoji picker
                    final e = await _pickEmoji(context);
                    if (e != null) setState(() => _newTagEmoji = e);
                  },
                  onSave: () => _saveNewTag(context),
                  onCancel: () {
                    setState(() {
                      _showNewTagForm = false;
                      _newTagNameCtrl.clear();
                      _newTagEmoji = '';
                    });
                  },
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add, size: 18),
                title: const Text('New tag'),
                onTap: () => setState(() => _showNewTagForm = true),
              ),
            ],
          ),
        ),

        const Divider(height: 1),
        // Footer
        SafeArea(
          top: false,
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.settings, size: 18),
                title: const Text('Settings'),
                onTap: widget.onSettings,
              ),
              if (widget.onAdmin != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.admin_panel_settings, size: 18),
                  title: const Text('Admin'),
                  onTap: widget.onAdmin,
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, size: 18),
                title: Text('Sign out (${widget.user})'),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveNewTag(BuildContext ctx) async {
    if (_newTagNameCtrl.text.trim().isEmpty) return;
    setState(() => _savingTag = true);
    try {
      await ref.read(tagsProvider.notifier).create(
            _newTagNameCtrl.text.trim(),
            _newTagEmoji,
          );
    } catch (_) {}
    setState(() {
      _savingTag = false;
      _showNewTagForm = false;
      _newTagNameCtrl.clear();
      _newTagEmoji = '';
    });
  }

  Future<String?> _pickEmoji(BuildContext context) {
    final emojis = [
      '😀','😂','😍','🤔','😎','🥳','🌟','🔥','🌊','🌈',
      '☀️','🌙','📚','💡','🔑','📷','🎵','💻','📱','❤️',
      '💙','💛','💚','🖤','💜','🧡','♾️','⚽','🎮','🎨',
      '🎸','🏋️','🎯','🧩','🏠','🚗','✈️','🗺️','🏔️','🏖️',
    ];
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          crossAxisCount: 8,
          shrinkWrap: true,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, e),
                    child: Center(
                      child: Text(e,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------

class _NewTagForm extends StatelessWidget {
  const _NewTagForm({
    required this.nameCtrl,
    required this.emoji,
    required this.saving,
    required this.onEmojiTap,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController nameCtrl;
  final String emoji;
  final bool saving;
  final VoidCallback onEmojiTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEmojiTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(emoji.isNotEmpty ? emoji : '🏷️',
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
                hintText: 'Tag name',
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          saving
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: onSave),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.onTap,
    required this.onDelete,
  });

  final List<Note> notes;
  final Function(Note) onTap;
  final Function(Note) onDelete;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No notes yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return LayoutBuilder(builder: (ctx, constraints) {
      final columns = (constraints.maxWidth / 180).floor().clamp(2, 4);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: notes.length,
        itemBuilder: (ctx, i) => NoteCard(
          note: notes[i],
          onTap: () => onTap(notes[i]),
          onDelete: () => onDelete(notes[i]),
        ),
      );
    });
  }
}
