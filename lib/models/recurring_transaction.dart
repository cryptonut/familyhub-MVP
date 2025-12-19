import 'package:cloud_firestore/cloud_firestore.dart';
import 'budget_transaction.dart';

/// Frequency options for recurring transactions
enum RecurringFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
}

/// Recurring transaction model for budget system
/// Represents a template for automatically creating budget transactions
class RecurringTransaction {
  final String id;
  final String budgetId;
  final String itemId; // Budget item this recurring transaction is linked to
  final String? categoryId; // Optional category
  final TransactionType type; // 'income' or 'expense'
  final double amount;
  final String description;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate; // Optional end date
  final DateTime? nextOccurrence; // Next date this transaction should be created
  final bool isActive;
  final String? userId; // Who this transaction is for
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  RecurringTransaction({
    required this.id,
    required this.budgetId,
    required this.itemId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.description,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.nextOccurrence,
    this.isActive = true,
    this.userId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'itemId': itemId,
        'categoryId': categoryId,
        'type': type.name,
        'amount': amount,
        'description': description,
        'frequency': frequency.name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'nextOccurrence': nextOccurrence != null ? Timestamp.fromDate(nextOccurrence!) : null,
        'isActive': isActive,
        'userId': userId,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'metadata': metadata,
      };

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    try {
      // Handle dates
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

      DateTime? endDate;
      if (json['endDate'] != null) {
        if (json['endDate'] is Timestamp) {
          endDate = (json['endDate'] as Timestamp).toDate();
        } else if (json['endDate'] is String) {
          endDate = DateTime.parse(json['endDate'] as String);
        }
      }

      DateTime? nextOccurrence;
      if (json['nextOccurrence'] != null) {
        if (json['nextOccurrence'] is Timestamp) {
          nextOccurrence = (json['nextOccurrence'] as Timestamp).toDate();
        } else if (json['nextOccurrence'] is String) {
          nextOccurrence = DateTime.parse(json['nextOccurrence'] as String);
        }
      }

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

      DateTime? updatedAt;
      if (json['updatedAt'] != null) {
        if (json['updatedAt'] is Timestamp) {
          updatedAt = (json['updatedAt'] as Timestamp).toDate();
        } else if (json['updatedAt'] is String) {
          updatedAt = DateTime.parse(json['updatedAt'] as String);
        }
      }

      return RecurringTransaction(
        id: json['id'] as String? ?? '',
        budgetId: json['budgetId'] as String? ?? '',
        itemId: json['itemId'] as String? ?? '',
        categoryId: json['categoryId'] as String?,
        type: TransactionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TransactionType.expense,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String? ?? '',
        frequency: RecurringFrequency.values.firstWhere(
          (e) => e.name == json['frequency'],
          orElse: () => RecurringFrequency.monthly,
        ),
        startDate: startDate,
        endDate: endDate,
        nextOccurrence: nextOccurrence,
        isActive: json['isActive'] as bool? ?? true,
        userId: json['userId'] as String?,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      throw FormatException('Error parsing RecurringTransaction: $e');
    }
  }

  RecurringTransaction copyWith({
    String? id,
    String? budgetId,
    String? itemId,
    String? categoryId,
    TransactionType? type,
    double? amount,
    String? description,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextOccurrence,
    bool? isActive,
    String? userId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      itemId: itemId ?? this.itemId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      isActive: isActive ?? this.isActive,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Calculate the next occurrence date based on frequency
  DateTime calculateNextOccurrence({DateTime? fromDate}) {
    final baseDate = fromDate ?? (nextOccurrence ?? startDate);
    
    switch (frequency) {
      case RecurringFrequency.daily:
        return baseDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return baseDate.add(const Duration(days: 7));
      case RecurringFrequency.biweekly:
        return baseDate.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        return DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      case RecurringFrequency.quarterly:
        return DateTime(baseDate.year, baseDate.month + 3, baseDate.day);
      case RecurringFrequency.yearly:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
    }
  }

  /// Check if this recurring transaction should be processed today
  bool shouldProcessToday() {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;
    
    final next = nextOccurrence ?? startDate;
    return next.isBefore(DateTime.now()) || 
           next.isAtSameMomentAs(DateTime.now()) ||
           (next.year == DateTime.now().year && 
            next.month == DateTime.now().month && 
            next.day == DateTime.now().day);
  }
}

