import 'package:cloud_firestore/cloud_firestore.dart';

/// Custody schedule for co-parenting hub
class CustodySchedule {
  final String id;
  final String hubId;
  final String childId; // User ID of the child
  final ScheduleType type;
  final Map<String, String> weeklySchedule; // dayOfWeek -> parentId
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ScheduleException> exceptions; // Holidays, special dates
  final DateTime createdAt;
  final String createdBy;

  CustodySchedule({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.type,
    this.weeklySchedule = const {},
    this.startDate,
    this.endDate,
    this.exceptions = const [],
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'type': type.name,
        'weeklySchedule': weeklySchedule,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'exceptions': exceptions.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory CustodySchedule.fromJson(Map<String, dynamic> json) => CustodySchedule(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        childId: json['childId'] as String,
        type: ScheduleType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ScheduleType.weekOnWeekOff,
        ),
        weeklySchedule: Map<String, String>.from(json['weeklySchedule'] as Map? ?? {}),
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        exceptions: (json['exceptions'] as List<dynamic>?)
                ?.map((e) => ScheduleException.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum ScheduleType {
  weekOnWeekOff,    // Alternating weeks
  twoTwoThree,      // 2-2-3 schedule
  everyOtherWeekend, // Every other weekend
  custom,           // Custom schedule
}

/// Schedule exception (holidays, special dates)
class ScheduleException {
  final DateTime date;
  final String parentId; // Who has custody on this date
  final String? reason; // e.g., "Holiday", "Special event"
  final bool isApproved;

  ScheduleException({
    required this.date,
    required this.parentId,
    this.reason,
    this.isApproved = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'parentId': parentId,
        if (reason != null) 'reason': reason,
        'isApproved': isApproved,
      };

  factory ScheduleException.fromJson(Map<String, dynamic> json) => ScheduleException(
        date: DateTime.parse(json['date'] as String),
        parentId: json['parentId'] as String,
        reason: json['reason'] as String?,
        isApproved: json['isApproved'] as bool? ?? false,
      );
}

/// Schedule change request
class ScheduleChangeRequest {
  final String id;
  final String hubId;
  final String childId;
  final DateTime requestedDate;
  final String requestedBy; // Parent requesting change
  final String? swapWithDate; // If swapping, the date to swap with
  final String? reason;
  final ScheduleChangeStatus status;
  final String? respondedBy;
  final DateTime? respondedAt;
  final DateTime createdAt;

  ScheduleChangeRequest({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.requestedDate,
    required this.requestedBy,
    this.swapWithDate,
    this.reason,
    this.status = ScheduleChangeStatus.pending,
    this.respondedBy,
    this.respondedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'requestedDate': requestedDate.toIso8601String(),
        'requestedBy': requestedBy,
        if (swapWithDate != null) 'swapWithDate': swapWithDate,
        if (reason != null) 'reason': reason,
        'status': status.name,
        if (respondedBy != null) 'respondedBy': respondedBy,
        if (respondedAt != null) 'respondedAt': respondedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScheduleChangeRequest.fromJson(Map<String, dynamic> json) =>
      ScheduleChangeRequest(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        childId: json['childId'] as String,
        requestedDate: DateTime.parse(json['requestedDate'] as String),
        requestedBy: json['requestedBy'] as String,
        swapWithDate: json['swapWithDate'] as String?,
        reason: json['reason'] as String?,
        status: ScheduleChangeStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ScheduleChangeStatus.pending,
        ),
        respondedBy: json['respondedBy'] as String?,
        respondedAt: json['respondedAt'] != null
            ? DateTime.parse(json['respondedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

enum ScheduleChangeStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

/// Co-parenting expense
class CoparentingExpense {
  final String id;
  final String hubId;
  final String childId; // Expense related to which child
  final String category; // medical, education, activities, etc.
  final String description;
  final double amount;
  final String paidBy; // Parent who paid
  final double splitRatio; // Percentage (e.g., 50 for 50/50)
  final String? receiptUrl;
  final DateTime expenseDate;
  final ExpenseStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final String createdBy;

  CoparentingExpense({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.category,
    required this.description,
    required this.amount,
    required this.paidBy,
    this.splitRatio = 50.0, // Default 50/50
    this.receiptUrl,
    required this.expenseDate,
    this.status = ExpenseStatus.pending,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.createdBy,
  });

  /// Calculate amount owed by the other parent
  double get amountOwed {
    return amount * (splitRatio / 100);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'category': category,
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitRatio': splitRatio,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        'expenseDate': expenseDate.toIso8601String(),
        'status': status.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
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
        approvedBy: json['approvedBy'] as String?,
        approvedAt: json['approvedAt'] != null
            ? DateTime.parse(json['approvedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum ExpenseStatus {
  pending,    // Awaiting approval
  approved,   // Approved by other parent
  rejected,   // Rejected by other parent
  paid,       // Reimbursement paid
}


