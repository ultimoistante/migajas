import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:open_filex/open_filex.dart';
import '../api/attachments_repository.dart';
import '../models/attachment.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

class AttachmentPanel extends ConsumerStatefulWidget {
  const AttachmentPanel({
    super.key,
    required this.note,
    required this.attachments,
    required this.onChanged,
  });

  final Note note;
  final List<Attachment> attachments;
  final ValueChanged<List<Attachment>> onChanged;

  @override
  ConsumerState<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends ConsumerState<AttachmentPanel> {
  final _repo = AttachmentsRepository();
  final _player = AudioPlayer();
  String? _playingId;
  bool _uploading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final att = await _repo.uploadBytes(
        widget.note.id,
        f.bytes!,
        f.name,
        _guessMime(f.name),
      );
      final updated = [...widget.attachments, att];
      widget.onChanged(updated);
      ref.read(notesProvider.notifier).patchAttachmentCount(widget.note.id, 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await img.readAsBytes();
      final att = await _repo.uploadBytes(
          widget.note.id, bytes, img.name, 'image/jpeg');
      final updated = [...widget.attachments, att];
      widget.onChanged(updated);
      ref.read(notesProvider.notifier).patchAttachmentCount(widget.note.id, 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(Attachment att) async {
    try {
      await _repo.delete(att.id);
      final updated =
          widget.attachments.where((a) => a.id != att.id).toList();
      widget.onChanged(updated);
      ref
          .read(notesProvider.notifier)
          .patchAttachmentCount(widget.note.id, -1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _open(Attachment att) async {
    try {
      final bytes = await _repo.downloadBytes(att.id);
      final tmp = await File(
              '${Directory.systemTemp.path}/${att.originalName}')
          .writeAsBytes(bytes);
      await OpenFilex.open(tmp.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cannot open: $e')));
      }
    }
  }

  Future<void> _toggleAudio(Attachment att) async {
    if (_playingId == att.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      final bytes = await _repo.downloadBytes(att.id);
      final tmp = await File(
              '${Directory.systemTemp.path}/${att.originalName}')
          .writeAsBytes(bytes);
      await _player.play(DeviceFileSource(tmp.path));
      setState(() => _playingId = att.id);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingId = null);
      });
    }
  }

  String _guessMime(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload buttons row
        Row(
          children: [
            TextButton.icon(
              onPressed: _uploading ? null : _pickerMenu,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file, size: 18),
              label: Text(_uploading ? 'Uploading…' : 'Add file'),
            ),
            TextButton.icon(
              onPressed: _uploading ? null : _pickImage,
              icon: const Icon(Icons.image, size: 18),
              label: const Text('Photo'),
            ),
          ],
        ),
        // Attachment list
        if (widget.attachments.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.attachments.length,
            itemBuilder: (ctx, i) {
              final att = widget.attachments[i];
              return ListTile(
                dense: true,
                leading: Text(att.typeEmoji, style: const TextStyle(fontSize: 20)),
                title: Text(att.originalName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(att.readableSize),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (att.isAudio)
                      IconButton(
                        icon: Icon(_playingId == att.id
                            ? Icons.stop
                            : Icons.play_arrow),
                        onPressed: () => _toggleAudio(att),
                      ),
                    if (!att.isAudio)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => _open(att),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _delete(att),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _pickerMenu() => _uploadFile(); // could show bottom sheet with options
}
