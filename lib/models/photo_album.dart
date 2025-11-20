/// Model for a photo album
class PhotoAlbum {
  final String id;
  final String familyId;
  final String name;
  final String? description;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? coverPhotoId; // ID of photo to use as cover
  final int photoCount;
  final DateTime? lastPhotoAddedAt;

  PhotoAlbum({
    required this.id,
    required this.familyId,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.coverPhotoId,
    this.photoCount = 0,
    this.lastPhotoAddedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'name': name,
        if (description != null) 'description': description,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
        if (coverPhotoId != null) 'coverPhotoId': coverPhotoId,
        'photoCount': photoCount,
        if (lastPhotoAddedAt != null) 'lastPhotoAddedAt': lastPhotoAddedAt!.toIso8601String(),
      };

  factory PhotoAlbum.fromJson(Map<String, dynamic> json) => PhotoAlbum(
        id: json['id'] as String,
        familyId: json['familyId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        createdBy: json['createdBy'] as String,
        createdByName: json['createdByName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        coverPhotoId: json['coverPhotoId'] as String?,
        photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
        lastPhotoAddedAt: json['lastPhotoAddedAt'] != null
            ? DateTime.parse(json['lastPhotoAddedAt'] as String)
            : null,
      );

  PhotoAlbum copyWith({
    String? id,
    String? familyId,
    String? name,
    String? description,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? coverPhotoId,
    int? photoCount,
    DateTime? lastPhotoAddedAt,
  }) =>
      PhotoAlbum(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        name: name ?? this.name,
        description: description ?? this.description,
        createdBy: createdBy ?? this.createdBy,
        createdByName: createdByName ?? this.createdByName,
        createdAt: createdAt ?? this.createdAt,
        coverPhotoId: coverPhotoId ?? this.coverPhotoId,
        photoCount: photoCount ?? this.photoCount,
        lastPhotoAddedAt: lastPhotoAddedAt ?? this.lastPhotoAddedAt,
      );
}

