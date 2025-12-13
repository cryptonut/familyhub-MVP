import 'package:cloud_firestore/cloud_firestore.dart';

/// Budget model representing a family, individual, or project budget
class Budget {
  final String id;
  final String familyId;
  final String name;
  final String description;
  final BudgetType type; // 'family', 'individual', 'project'
  final String? userId; // For individual budgets
  final String? projectId; // For project budgets
  final double totalAmount; // Total budget amount
  final DateTime startDate;
  final DateTime endDate;
  final String period; // 'weekly', 'monthly', 'yearly', 'custom'
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, double> categoryLimits; // categoryId -> limit amount
  final String? currency; // Default: 'AUD'
  final double adherenceThreshold; // Default % over budget before warning (default: 5%)
  final int itemCount; // Denormalized: total number of items
  final int completedItemCount; // Denormalized: number of completed items

  Budget({
    required this.id,
    required this.familyId,
    required this.name,
    this.description = '',
    required this.type,
    this.userId,
    this.projectId,
    required this.totalAmount,
    required this.startDate,
    required this.endDate,
    required this.period,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.categoryLimits = const {},
    this.currency = 'AUD',
    this.adherenceThreshold = 5.0, // Default 5% over budget
    this.itemCount = 0,
    this.completedItemCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'name': name,
        'description': description,
        'type': type.name,
        'userId': userId,
        'projectId': projectId,
        'totalAmount': totalAmount,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'period': period,
        'isActive': isActive,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'categoryLimits': categoryLimits,
        'currency': currency,
        'adherenceThreshold': adherenceThreshold,
        'itemCount': itemCount,
        'completedItemCount': completedItemCount,
      };

  factory Budget.fromJson(Map<String, dynamic> json) {
    try {
      // Handle createdAt
      DateTime createdAt;
      if (json['createdAt'] != null) {
        if (json['createdAt'] is Timestamp) {
          createdAt = (json['createdAt'] as Timestamp).toDate();
        } else if (json['createdAt'] is String) {
          createdAt = DateTime.parse(json['createdAt'] as String);
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      // Handle updatedAt
      DateTime? updatedAt;
      if (json['updatedAt'] != null) {
        if (json['updatedAt'] is Timestamp) {
          updatedAt = (json['updatedAt'] as Timestamp).toDate();
        } else if (json['updatedAt'] is String) {
          updatedAt = DateTime.parse(json['updatedAt'] as String);
        }
      }

      // Handle startDate
      DateTime startDate;
      if (json['startDate'] != null) {
        if (json['startDate'] is Timestamp) {
          startDate = (json['startDate'] as Timestamp).toDate();
        } else if (json['startDate'] is String) {
          startDate = DateTime.parse(json['startDate'] as String);
        } else {
          startDate = DateTime.now();
        }
      } else {
        startDate = DateTime.now();
      }

      // Handle endDate
      DateTime endDate;
      if (json['endDate'] != null) {
        if (json['endDate'] is Timestamp) {
          endDate = (json['endDate'] as Timestamp).toDate();
        } else if (json['endDate'] is String) {
          endDate = DateTime.parse(json['endDate'] as String);
        } else {
          endDate = startDate.add(const Duration(days: 30));
        }
      } else {
        endDate = startDate.add(const Duration(days: 30));
      }

      // Handle categoryLimits
      Map<String, double> categoryLimits = {};
      if (json['categoryLimits'] != null) {
        if (json['categoryLimits'] is Map) {
          (json['categoryLimits'] as Map).forEach((key, value) {
            if (value is num) {
              categoryLimits[key.toString()] = value.toDouble();
            }
          });
        }
      }

      return Budget(
        id: json['id'] as String? ?? '',
        familyId: json['familyId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        type: BudgetType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => BudgetType.family,
        ),
        userId: json['userId'] as String?,
        projectId: json['projectId'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        startDate: startDate,
        endDate: endDate,
        period: json['period'] as String? ?? 'monthly',
        isActive: json['isActive'] as bool? ?? true,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        categoryLimits: categoryLimits,
        currency: json['currency'] as String? ?? 'AUD',
        adherenceThreshold: (json['adherenceThreshold'] as num?)?.toDouble() ?? 5.0,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        completedItemCount: (json['completedItemCount'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw FormatException('Error parsing Budget: $e');
    }
  }

  Budget copyWith({
    String? id,
    String? familyId,
    String? name,
    String? description,
    BudgetType? type,
    String? userId,
    String? projectId,
    double? totalAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? period,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, double>? categoryLimits,
    String? currency,
    double? adherenceThreshold,
    int? itemCount,
    int? completedItemCount,
  }) {
    return Budget(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      totalAmount: totalAmount ?? this.totalAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      period: period ?? this.period,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryLimits: categoryLimits ?? this.categoryLimits,
      currency: currency ?? this.currency,
      adherenceThreshold: adherenceThreshold ?? this.adherenceThreshold,
      itemCount: itemCount ?? this.itemCount,
      completedItemCount: completedItemCount ?? this.completedItemCount,
    );
  }

  /// Calculate progress as percentage of items completed
  double get itemProgressPercentage {
    if (itemCount == 0) return 0.0;
    return (completedItemCount / itemCount) * 100;
  }

  /// Calculate progress as percentage of budget spent
  /// Note: This requires actual spending data, calculated in service layer
}

enum BudgetType {
  family,
  individual,
  project,
}

