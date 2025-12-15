/// Educational resource for homeschooling hub
class EducationalResource {
  final String id;
  final String hubId;
  final String title;
  final String? description;
  final ResourceType type;
  final String? url; // For links
  final String? fileUrl; // For uploaded documents
  final String? thumbnailUrl;
  final List<String> subjects; // Subjects this resource relates to
  final String? gradeLevel; // Target grade level
  final List<String> tags; // Searchable tags
  final DateTime createdAt;
  final String createdBy;
  final int viewCount;
  final DateTime? lastViewedAt;

  EducationalResource({
    required this.id,
    required this.hubId,
    required this.title,
    this.description,
    required this.type,
    this.url,
    this.fileUrl,
    this.thumbnailUrl,
    this.subjects = const [],
    this.gradeLevel,
    this.tags = const [],
    required this.createdAt,
    required this.createdBy,
    this.viewCount = 0,
    this.lastViewedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'title': title,
        'description': description,
        'type': type.name,
        'url': url,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'subjects': subjects,
        'gradeLevel': gradeLevel,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'viewCount': viewCount,
        'lastViewedAt': lastViewedAt?.toIso8601String(),
      };

  factory EducationalResource.fromJson(Map<String, dynamic> json) =>
      EducationalResource(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        type: ResourceType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ResourceType.link,
        ),
        url: json['url'] as String?,
        fileUrl: json['fileUrl'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        subjects: List<String>.from(json['subjects'] as List? ?? []),
        gradeLevel: json['gradeLevel'] as String?,
        tags: List<String>.from(json['tags'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        lastViewedAt: json['lastViewedAt'] != null
            ? DateTime.parse(json['lastViewedAt'] as String)
            : null,
      );
}

enum ResourceType {
  link, // Online learning material
  document, // PDF, worksheet, etc.
  video, // Video lesson
  image, // Image resource
  other,
}

extension ResourceTypeExtension on ResourceType {
  String get displayName {
    switch (this) {
      case ResourceType.link:
        return 'Link';
      case ResourceType.document:
        return 'Document';
      case ResourceType.video:
        return 'Video';
      case ResourceType.image:
        return 'Image';
      case ResourceType.other:
        return 'Other';
    }
  }
}

