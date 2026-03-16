class Attachment {
  final String id;
  final String noteId;
  final String originalName;
  final String mimeType;
  final int size;
  final String createdAt;

  const Attachment({
    required this.id,
    required this.noteId,
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        noteId: j['note_id'] as String? ?? '',
        originalName: j['original_name'] as String? ?? '',
        mimeType: j['mime_type'] as String? ?? 'application/octet-stream',
        size: (j['size'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String? ?? '',
      );

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isPdf => mimeType.contains('pdf');

  String get typeEmoji {
    if (isAudio) return '🎵';
    if (isImage) return '🖼️';
    if (isVideo) return '🎬';
    if (isPdf) return '📄';
    return '📎';
  }

  String get readableSize {
    if (size < 1024) return '${size} B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
