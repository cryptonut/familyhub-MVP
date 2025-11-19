class RecurringPayment {
  final String id;
  final String fromUserId; // Banker who set up the payment
  final String toUserId; // Recipient (kid)
  final double amount;
  final String frequency; // 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime? nextPaymentDate;
  final bool isActive;
  final String? notes; // Optional notes
  final DateTime createdAt;
  final DateTime? lastPaymentDate; // When last payment was made

  RecurringPayment({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.nextPaymentDate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    this.lastPaymentDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
        'frequency': frequency,
        'startDate': startDate.toIso8601String(),
        'nextPaymentDate': nextPaymentDate?.toIso8601String(),
        'isActive': isActive,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      };

  factory RecurringPayment.fromJson(Map<String, dynamic> json) {
    return RecurringPayment(
      id: json['id'] as String? ?? '',
      fromUserId: json['fromUserId'] as String? ?? '',
      toUserId: json['toUserId'] as String? ?? '',
      amount: json['amount'] != null
          ? (json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0)
          : 0.0,
      frequency: json['frequency'] as String? ?? 'weekly',
      startDate: json['startDate'] != null
          ? (json['startDate'] is String
              ? DateTime.parse(json['startDate'] as String)
              : json['startDate'] as DateTime)
          : DateTime.now(),
      nextPaymentDate: json['nextPaymentDate'] != null
          ? (json['nextPaymentDate'] is String
              ? DateTime.parse(json['nextPaymentDate'] as String)
              : json['nextPaymentDate'] as DateTime?)
          : null,
      isActive: json['isActive'] == true || json['isActive'] == 'true',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : json['createdAt'] as DateTime)
          : DateTime.now(),
      lastPaymentDate: json['lastPaymentDate'] != null
          ? (json['lastPaymentDate'] is String
              ? DateTime.parse(json['lastPaymentDate'] as String)
              : json['lastPaymentDate'] as DateTime?)
          : null,
    );
  }

  RecurringPayment copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    double? amount,
    String? frequency,
    DateTime? startDate,
    DateTime? nextPaymentDate,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? lastPaymentDate,
  }) =>
      RecurringPayment(
        id: id ?? this.id,
        fromUserId: fromUserId ?? this.fromUserId,
        toUserId: toUserId ?? this.toUserId,
        amount: amount ?? this.amount,
        frequency: frequency ?? this.frequency,
        startDate: startDate ?? this.startDate,
        nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      );

  /// Calculate the next payment date based on frequency
  DateTime calculateNextPaymentDate() {
    if (lastPaymentDate != null) {
      return _addPeriod(lastPaymentDate!);
    }
    if (nextPaymentDate != null && nextPaymentDate!.isAfter(DateTime.now())) {
      return nextPaymentDate!;
    }
    return _addPeriod(startDate);
  }

  DateTime _addPeriod(DateTime date) {
    switch (frequency) {
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(date.year, date.month + 1, date.day);
      default:
        return date.add(const Duration(days: 7));
    }
  }
}

