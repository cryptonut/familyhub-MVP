/// Model for a comment on a photo
class PhotoComment {
  final String id;
  final String photoId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;

  PhotoComment({
    required this.id,
    required this.photoId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.editedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'photoId': photoId,
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };

  factory PhotoComment.fromJson(Map<String, dynamic> json) => PhotoComment(
        id: json['id'] as String,
        photoId: json['photoId'] as String,
        authorId: json['authorId'] as String,
        authorName: json['authorName'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
      );

  PhotoComment copyWith({
    String? id,
    String? photoId,
    String? authorId,
    String? authorName,
    String? content,
    DateTime? createdAt,
    DateTime? editedAt,
  }) =>
      PhotoComment(
        id: id ?? this.id,
        photoId: photoId ?? this.photoId,
        authorId: authorId ?? this.authorId,
        authorName: authorName ?? this.authorName,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        editedAt: editedAt ?? this.editedAt,
      );
}

