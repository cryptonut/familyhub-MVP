import 'package:cloud_firestore/cloud_firestore.dart';

/// Budget item status
enum BudgetItemStatus {
  pending,    // Not started
  inProgress, // Partially complete (has sub-items that are complete)
  complete,   // Fully complete (all sub-items complete)
}

/// Budget item model representing a granular item within a budget
/// Items can have sub-items for hierarchical organization
class BudgetItem {
  final String id;
  final String budgetId;
  final String name;
  final String description;
  final double estimatedAmount; // Planned/estimated cost
  final double? actualAmount; // User-attested actual cost (null until completed)
  final BudgetItemStatus status;
  final String? parentItemId; // For sub-items (null for top-level items)
  final int order; // For sorting/reordering
  final double adherenceThreshold; // % over budget before warning (default from budget)
  final String? receiptUrl; // Receipt photo URL
  final String? receiptId; // Receipt ID in Firebase Storage
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? completedBy;
  final List<String> subItemIds; // IDs of child items
  final bool hasSubItems; // Denormalized: true if subItemIds is not empty

  BudgetItem({
    required this.id,
    required this.budgetId,
    required this.name,
    this.description = '',
    required this.estimatedAmount,
    this.actualAmount,
    this.status = BudgetItemStatus.pending,
    this.parentItemId,
    this.order = 0,
    this.adherenceThreshold = 5.0, // Default 5% over budget
    this.receiptUrl,
    this.receiptId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.completedBy,
    List<String>? subItemIds,
  }) : subItemIds = subItemIds ?? [],
       hasSubItems = (subItemIds?.isNotEmpty ?? false);

  /// Calculate adherence percentage
  /// Returns positive if over budget, negative if under budget
  double get adherencePercentage {
    if (actualAmount == null || estimatedAmount == 0) return 0.0;
    return ((actualAmount! - estimatedAmount) / estimatedAmount) * 100;
  }

  /// Get adherence status (green/yellow/red)
  BudgetAdherenceStatus get adherenceStatus {
    if (actualAmount == null) return BudgetAdherenceStatus.onTrack;
    
    final percentage = adherencePercentage;
    if (percentage <= 0) {
      return BudgetAdherenceStatus.onTrack; // On or under budget
    } else if (percentage <= adherenceThreshold) {
      return BudgetAdherenceStatus.warning; // Up to threshold % over
    } else {
      return BudgetAdherenceStatus.overBudget; // More than threshold % over
    }
  }

  /// Check if item is complete (all sub-items must be complete)
  bool get isComplete => status == BudgetItemStatus.complete;

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'description': description,
        'estimatedAmount': estimatedAmount,
        'actualAmount': actualAmount,
        'status': status.name,
        'parentItemId': parentItemId ?? null, // Explicitly set to null if not provided
        'order': order,
        'adherenceThreshold': adherenceThreshold,
        'receiptUrl': receiptUrl,
        'receiptId': receiptId,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'completedBy': completedBy,
        'subItemIds': subItemIds,
        'hasSubItems': hasSubItems,
      };

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
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

      // Handle status
      BudgetItemStatus status = BudgetItemStatus.pending;
      if (json['status'] != null) {
        try {
          status = BudgetItemStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => BudgetItemStatus.pending,
          );
        } catch (e) {
          status = BudgetItemStatus.pending;
        }
      }

      // Handle subItemIds
      List<String> subItemIds = [];
      if (json['subItemIds'] != null && json['subItemIds'] is List) {
        subItemIds = (json['subItemIds'] as List).map((e) => e.toString()).toList();
      }

      return BudgetItem(
        id: json['id'] as String? ?? '',
        budgetId: json['budgetId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        estimatedAmount: (json['estimatedAmount'] as num?)?.toDouble() ?? 0.0,
        actualAmount: (json['actualAmount'] as num?)?.toDouble(),
        status: status,
        parentItemId: json['parentItemId'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        adherenceThreshold: (json['adherenceThreshold'] as num?)?.toDouble() ?? 5.0,
        receiptUrl: json['receiptUrl'] as String?,
        receiptId: json['receiptId'] as String?,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: completedAt,
        completedBy: json['completedBy'] as String?,
        subItemIds: subItemIds,
      );
    } catch (e) {
      throw FormatException('Error parsing BudgetItem: $e');
    }
  }

  BudgetItem copyWith({
    String? id,
    String? budgetId,
    String? name,
    String? description,
    double? estimatedAmount,
    double? actualAmount,
    BudgetItemStatus? status,
    String? parentItemId,
    int? order,
    double? adherenceThreshold,
    String? receiptUrl,
    String? receiptId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? completedBy,
    List<String>? subItemIds,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      description: description ?? this.description,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      status: status ?? this.status,
      parentItemId: parentItemId ?? this.parentItemId,
      order: order ?? this.order,
      adherenceThreshold: adherenceThreshold ?? this.adherenceThreshold,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptId: receiptId ?? this.receiptId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      subItemIds: subItemIds ?? this.subItemIds,
    );
  }
}

/// Budget adherence status for visual indicators
enum BudgetAdherenceStatus {
  onTrack,    // Green: On or under budget
  warning,    // Yellow: Up to threshold % over
  overBudget, // Red: More than threshold % over
}

