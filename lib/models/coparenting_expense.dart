import 'package:uuid/uuid.dart';

enum ExpenseStatus {
  pending,
  approved,
  rejected,
  paid,
}

class CoparentingExpense {
  final String id;
  final String hubId;
  final String childId;
  final String category;
  final String description;
  final double amount;
  final String paidBy;
  final double splitRatio; // Percentage (e.g., 50.0 = 50%)
  final String? receiptUrl;
  final DateTime expenseDate;
  final ExpenseStatus status;
  final DateTime createdAt;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  CoparentingExpense({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.category,
    required this.description,
    required this.amount,
    required this.paidBy,
    this.splitRatio = 50.0,
    this.receiptUrl,
    required this.expenseDate,
    this.status = ExpenseStatus.pending,
    required this.createdAt,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'category': category,
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitRatio': splitRatio,
        'receiptUrl': receiptUrl,
        'expenseDate': expenseDate.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory CoparentingExpense.fromJson(Map<String, dynamic> json) =>
      CoparentingExpense(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        childId: json['childId'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        paidBy: json['paidBy'] as String,
        splitRatio: (json['splitRatio'] as num?)?.toDouble() ?? 50.0,
        receiptUrl: json['receiptUrl'] as String?,
        expenseDate: DateTime.parse(json['expenseDate'] as String),
        status: ExpenseStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ExpenseStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        approvedBy: json['approvedBy'] as String?,
        approvedAt: json['approvedAt'] != null
            ? DateTime.parse(json['approvedAt'] as String)
            : null,
        rejectionReason: json['rejectionReason'] as String?,
      );

  CoparentingExpense copyWith({
    String? id,
    String? hubId,
    String? childId,
    String? category,
    String? description,
    double? amount,
    String? paidBy,
    double? splitRatio,
    String? receiptUrl,
    DateTime? expenseDate,
    ExpenseStatus? status,
    DateTime? createdAt,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
  }) {
    return CoparentingExpense(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      childId: childId ?? this.childId,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      splitRatio: splitRatio ?? this.splitRatio,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      expenseDate: expenseDate ?? this.expenseDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}


