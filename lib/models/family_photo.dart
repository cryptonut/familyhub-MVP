/// Model for a family photo
class FamilyPhoto {
  final String id;
  final String familyId;
  final String uploadedBy;
  final String uploadedByName;
  final String? albumId; // Optional album grouping
  final String imageUrl; // Firebase Storage URL
  final String? thumbnailUrl; // Optional thumbnail URL
  final String? caption;
  final DateTime uploadedAt;
  final List<String> taggedMemberIds; // Family members tagged in photo
  final int viewCount;
  final DateTime? lastViewedAt;

  FamilyPhoto({
    required this.id,
    required this.familyId,
    required this.uploadedBy,
    required this.uploadedByName,
    this.albumId,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.uploadedAt,
    this.caption,
    this.taggedMemberIds = const [],
    this.viewCount = 0,
    this.lastViewedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        if (albumId != null) 'albumId': albumId,
        'imageUrl': imageUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (caption != null) 'caption': caption,
        'uploadedAt': uploadedAt.toIso8601String(),
        'taggedMemberIds': taggedMemberIds,
        'viewCount': viewCount,
        if (lastViewedAt != null) 'lastViewedAt': lastViewedAt!.toIso8601String(),
      };

  factory FamilyPhoto.fromJson(Map<String, dynamic> json) => FamilyPhoto(
        id: json['id'] as String,
        familyId: json['familyId'] as String,
        uploadedBy: json['uploadedBy'] as String,
        uploadedByName: json['uploadedByName'] as String,
        albumId: json['albumId'] as String?,
        imageUrl: json['imageUrl'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        caption: json['caption'] as String?,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
        taggedMemberIds: List<String>.from(json['taggedMemberIds'] as List? ?? []),
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        lastViewedAt: json['lastViewedAt'] != null
            ? DateTime.parse(json['lastViewedAt'] as String)
            : null,
      );

  FamilyPhoto copyWith({
    String? id,
    String? familyId,
    String? uploadedBy,
    String? uploadedByName,
    String? albumId,
    String? imageUrl,
    String? thumbnailUrl,
    String? caption,
    DateTime? uploadedAt,
    List<String>? taggedMemberIds,
    int? viewCount,
    DateTime? lastViewedAt,
  }) =>
      FamilyPhoto(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        uploadedByName: uploadedByName ?? this.uploadedByName,
        albumId: albumId ?? this.albumId,
        imageUrl: imageUrl ?? this.imageUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        caption: caption ?? this.caption,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        taggedMemberIds: taggedMemberIds ?? this.taggedMemberIds,
        viewCount: viewCount ?? this.viewCount,
        lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      );
}

