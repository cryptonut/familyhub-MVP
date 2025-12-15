/// Child profile for co-parenting hub
class ChildProfile {
  final String id;
  final String hubId;
  final String name;
  final DateTime? dateOfBirth;
  final String? medicalInfo; // Allergies, medications, conditions
  final String? schoolName;
  final String? schoolGrade;
  final String? schoolContact;
  final List<String> activitySchedules; // Activity names/schedules
  final List<String> documentUrls; // Important documents (medical records, school reports, etc.)
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  ChildProfile({
    required this.id,
    required this.hubId,
    required this.name,
    this.dateOfBirth,
    this.medicalInfo,
    this.schoolName,
    this.schoolGrade,
    this.schoolContact,
    this.activitySchedules = const [],
    this.documentUrls = const [],
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'name': name,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        'medicalInfo': medicalInfo,
        'schoolName': schoolName,
        'schoolGrade': schoolGrade,
        'schoolContact': schoolContact,
        'activitySchedules': activitySchedules,
        'documentUrls': documentUrls,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'updatedBy': updatedBy,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        name: json['name'] as String,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.parse(json['dateOfBirth'] as String)
            : null,
        medicalInfo: json['medicalInfo'] as String?,
        schoolName: json['schoolName'] as String?,
        schoolGrade: json['schoolGrade'] as String?,
        schoolContact: json['schoolContact'] as String?,
        activitySchedules:
            List<String>.from(json['activitySchedules'] as List? ?? []),
        documentUrls: List<String>.from(json['documentUrls'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        updatedBy: json['updatedBy'] as String?,
      );

  ChildProfile copyWith({
    String? id,
    String? hubId,
    String? name,
    DateTime? dateOfBirth,
    String? medicalInfo,
    String? schoolName,
    String? schoolGrade,
    String? schoolContact,
    List<String>? activitySchedules,
    List<String>? documentUrls,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) =>
      ChildProfile(
        id: id ?? this.id,
        hubId: hubId ?? this.hubId,
        name: name ?? this.name,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        medicalInfo: medicalInfo ?? this.medicalInfo,
        schoolName: schoolName ?? this.schoolName,
        schoolGrade: schoolGrade ?? this.schoolGrade,
        schoolContact: schoolContact ?? this.schoolContact,
        activitySchedules: activitySchedules ?? this.activitySchedules,
        documentUrls: documentUrls ?? this.documentUrls,
        createdAt: createdAt ?? this.createdAt,
        createdBy: createdBy ?? this.createdBy,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy ?? this.updatedBy,
      );
}

