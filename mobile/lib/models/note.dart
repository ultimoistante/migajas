import 'tag.dart';

class Note {
  final String id;
  final String userId;
  final String title;
  final String? body; // null when secret + locked
  final bool isSecret;
  final bool isLocked;
  final bool isPinned;
  final String? color;
  final List<Tag> tags;
  final String createdAt;
  final String updatedAt;
  final int? attachmentCount;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.isSecret,
    required this.isLocked,
    required this.isPinned,
    this.color,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.attachmentCount,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String?,
        isSecret: (j['is_secret'] as bool?) ?? false,
        isLocked: (j['is_locked'] as bool?) ?? false,
        isPinned: (j['is_pinned'] as bool?) ?? false,
        color: j['color'] as String?,
        tags: (j['tags'] as List<dynamic>?)
                ?.map((t) => Tag.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: j['created_at'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
        attachmentCount: (j['attachment_count'] as num?)?.toInt(),
      );

  Note copyWith({
    String? title,
    String? body,
    bool clearBody = false,
    bool? isSecret,
    bool? isLocked,
    bool? isPinned,
    String? color,
    List<Tag>? tags,
    String? updatedAt,
    int? attachmentCount,
  }) =>
      Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        body: clearBody ? null : (body ?? this.body),
        isSecret: isSecret ?? this.isSecret,
        isLocked: isLocked ?? this.isLocked,
        isPinned: isPinned ?? this.isPinned,
        color: color ?? this.color,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        attachmentCount: attachmentCount ?? this.attachmentCount,
      );
}
