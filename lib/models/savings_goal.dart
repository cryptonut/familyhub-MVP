import 'package:cloud_firestore/cloud_firestore.dart';

/// Savings goal model (Premium feature)
class SavingsGoal {
  final String id;
  final String budgetId;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final bool isCompleted;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? icon; // Icon name or emoji
  final String color; // Hex color code

  SavingsGoal({
    required this.id,
    required this.budgetId,
    required this.name,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.isCompleted = false,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.icon,
    this.color = '#4CAF50', // Default green
  });

  /// Get progress percentage (0.0 to 1.0)
  double get progress => targetAmount > 0 
      ? (currentAmount / targetAmount).clamp(0.0, 1.0) 
      : 0.0;

  /// Get progress percentage as integer (0 to 100)
  int get progressPercent => (progress * 100).round();

  /// Check if goal is overdue
  bool get isOverdue => !isCompleted && DateTime.now().isAfter(targetDate);

  /// Get days remaining (negative if overdue)
  int get daysRemaining {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'description': description,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': Timestamp.fromDate(targetDate),
        'isCompleted': isCompleted,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'icon': icon,
        'color': color,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
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

      // Handle completedAt
      DateTime? completedAt;
      if (json['completedAt'] != null) {
        if (json['completedAt'] is Timestamp) {
          completedAt = (json['completedAt'] as Timestamp).toDate();
        } else if (json['completedAt'] is String) {
          completedAt = DateTime.parse(json['completedAt'] as String);
        }
      }

      // Handle targetDate
      DateTime targetDate;
      if (json['targetDate'] != null) {
        if (json['targetDate'] is Timestamp) {
          targetDate = (json['targetDate'] as Timestamp).toDate();
        } else if (json['targetDate'] is String) {
          targetDate = DateTime.parse(json['targetDate'] as String);
        } else {
          targetDate = DateTime.now().add(const Duration(days: 30));
        }
      } else {
        targetDate = DateTime.now().add(const Duration(days: 30));
      }

      return SavingsGoal(
        id: json['id'] as String? ?? '',
        budgetId: json['budgetId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
        currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
        targetDate: targetDate,
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: completedAt,
        icon: json['icon'] as String?,
        color: json['color'] as String? ?? '#4CAF50',
      );
    } catch (e) {
      throw FormatException('Error parsing SavingsGoal: $e');
    }
  }

  SavingsGoal copyWith({
    String? id,
    String? budgetId,
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    bool? isCompleted,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? icon,
    String? color,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

