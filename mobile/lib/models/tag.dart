class Tag {
  final String id;
  final String name;
  final String emoji;

  const Tag({required this.id, required this.name, required this.emoji});

  factory Tag.fromJson(Map<String, dynamic> j) => Tag(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '',
      );

  Tag copyWith({String? name, String? emoji}) =>
      Tag(id: id, name: name ?? this.name, emoji: emoji ?? this.emoji);
}
