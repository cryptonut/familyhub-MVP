import 'package:cloud_firestore/cloud_firestore.dart';

/// Budget transaction model for income and expenses
class BudgetTransaction {
  final String id;
  final String budgetId;
  final String itemId; // REQUIRED: Every transaction must be linked to a budget item
  final String? categoryId; // Optional category
  final TransactionType type; // 'income' or 'expense'
  final double amount;
  final String description;
  final DateTime date;
  final String? userId; // Who made the transaction
  final String? receiptUrl; // URL to receipt photo in Firebase Storage
  final String? receiptId; // Receipt ID in Firebase Storage
  final String? source; // 'manual', 'shopping', 'wallet', 'task', 'recurring'
  final String? sourceId; // ID of the source (e.g., shopping list ID, task ID)
  final bool isRecurring; // Whether this is part of a recurring transaction
  final String? recurringTransactionId; // ID of recurring transaction template
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata; // Additional data

  BudgetTransaction({
    required this.id,
    required this.budgetId,
    required this.itemId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.userId,
    this.receiptUrl,
    this.receiptId,
    this.source = 'manual',
    this.sourceId,
    this.isRecurring = false,
    this.recurringTransactionId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() =>       {
        'id': id,
        'budgetId': budgetId,
        'itemId': itemId,
        'categoryId': categoryId,
        'type': type.name,
        'amount': amount,
        'description': description,
        'date': Timestamp.fromDate(date),
        'userId': userId,
        'receiptUrl': receiptUrl,
        'receiptId': receiptId,
        'source': source,
        'sourceId': sourceId,
        'isRecurring': isRecurring,
        'recurringTransactionId': recurringTransactionId,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'metadata': metadata,
      };

  factory BudgetTransaction.fromJson(Map<String, dynamic> json) {
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

      // Handle date
      DateTime date;
      if (json['date'] != null) {
        if (json['date'] is Timestamp) {
          date = (json['date'] as Timestamp).toDate();
        } else if (json['date'] is String) {
          date = DateTime.parse(json['date'] as String);
        } else {
          date = DateTime.now();
        }
      } else {
        date = DateTime.now();
      }

      return BudgetTransaction(
        id: json['id'] as String? ?? '',
        budgetId: json['budgetId'] as String? ?? '',
        itemId: json['itemId'] as String? ?? '', // Required field
        categoryId: json['categoryId'] as String?,
        type: TransactionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TransactionType.expense,
        ),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String? ?? '',
        date: date,
        userId: json['userId'] as String?,
        receiptUrl: json['receiptUrl'] as String?,
        receiptId: json['receiptId'] as String?,
        source: json['source'] as String? ?? 'manual',
        sourceId: json['sourceId'] as String?,
        isRecurring: json['isRecurring'] as bool? ?? false,
        recurringTransactionId: json['recurringTransactionId'] as String?,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      throw FormatException('Error parsing BudgetTransaction: $e');
    }
  }

  BudgetTransaction copyWith({
    String? id,
    String? budgetId,
    String? itemId,
    String? categoryId,
    TransactionType? type,
    double? amount,
    String? description,
    DateTime? date,
    String? userId,
    String? receiptUrl,
    String? receiptId,
    String? source,
    String? sourceId,
    bool? isRecurring,
    String? recurringTransactionId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return BudgetTransaction(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      itemId: itemId ?? this.itemId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptId: receiptId ?? this.receiptId,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringTransactionId: recurringTransactionId ?? this.recurringTransactionId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum TransactionType {
  income,
  expense,
}

