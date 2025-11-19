class PayoutRequest {
  final String id;
  final String userId; // User requesting the payout
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final String? approvedBy; // User ID who approved/rejected
  final DateTime? approvedAt;
  final String? paymentMethod; // 'Cash', 'Bank', 'Other'
  final String? notes; // Additional notes from approver
  final DateTime createdAt;
  final String? rejectedReason; // Reason if rejected

  PayoutRequest({
    required this.id,
    required this.userId,
    required this.amount,
    this.status = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.rejectedReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'status': status,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'rejectedReason': rejectedReason,
      };

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      amount: json['amount'] != null
          ? (json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0)
          : 0.0,
      status: json['status'] as String? ?? 'pending',
      approvedBy: json['approvedBy'] as String?,
      approvedAt: json['approvedAt'] != null
          ? (json['approvedAt'] is String
              ? DateTime.parse(json['approvedAt'] as String)
              : json['approvedAt'] as DateTime?)
          : null,
      paymentMethod: json['paymentMethod'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'] as String)
              : json['createdAt'] as DateTime)
          : DateTime.now(),
      rejectedReason: json['rejectedReason'] as String?,
    );
  }

  PayoutRequest copyWith({
    String? id,
    String? userId,
    double? amount,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    String? rejectedReason,
  }) =>
      PayoutRequest(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        amount: amount ?? this.amount,
        status: status ?? this.status,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        rejectedReason: rejectedReason ?? this.rejectedReason,
      );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

