class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? dueDate;
  final String priority; // 'low', 'medium', 'high'
  final String assignedTo;
  final DateTime createdAt;
  final DateTime? completedAt;
  
  // Reward and claiming fields
  final double? reward; // Reward amount in AUD
  final String? claimedBy; // User ID who claimed the job
  final String? claimStatus; // 'pending', 'approved', 'rejected', null
  final bool needsApproval; // Whether job completion needs approval
  final bool requiresClaim; // Whether job must be claimed before completion
  final String? approvedBy; // User ID who approved the job
  final DateTime? approvedAt;
  final String? createdBy; // User ID who created the job
  final bool? isRefunded; // Whether the job has been refunded
  final String? refundReason; // Reason for refund (Job Cancelled, Job Not Completed, Other)
  final String? refundNote; // Additional note for refund
  final DateTime? refundedAt; // When the refund occurred

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.dueDate,
    this.priority = 'medium',
    this.assignedTo = '',
    required this.createdAt,
    this.completedAt,
    this.reward,
    this.claimedBy,
    this.claimStatus,
    this.needsApproval = false,
    this.requiresClaim = false,
    this.approvedBy,
    this.approvedAt,
    this.createdBy,
    this.isRefunded = false,
    this.refundReason,
    this.refundNote,
    this.refundedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
        'assignedTo': assignedTo,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'reward': reward,
        'claimedBy': claimedBy,
        'claimStatus': claimStatus,
        'needsApproval': needsApproval,
        'requiresClaim': requiresClaim,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
        'createdBy': createdBy,
        'isRefunded': isRefunded,
        'refundReason': refundReason,
        'refundNote': refundNote,
        'refundedAt': refundedAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    try {
      // Handle createdAt - it's required but might be missing
      DateTime createdAt;
      if (json['createdAt'] != null) {
        if (json['createdAt'] is String) {
          createdAt = DateTime.parse(json['createdAt'] as String);
        } else if (json['createdAt'] is DateTime) {
          createdAt = json['createdAt'] as DateTime;
        } else {
          // Fallback to now if createdAt is invalid
          createdAt = DateTime.now();
        }
      } else {
        // If createdAt is missing, use current time
        createdAt = DateTime.now();
      }
      
      return Task(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isCompleted: json['isCompleted'] == true || json['isCompleted'] == 'true',
        dueDate: json['dueDate'] != null
            ? (json['dueDate'] is String 
                ? DateTime.parse(json['dueDate'] as String)
                : json['dueDate'] as DateTime?)
            : null,
        priority: json['priority'] as String? ?? 'medium',
        assignedTo: json['assignedTo'] as String? ?? '',
        createdAt: createdAt,
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] is String
                ? DateTime.parse(json['completedAt'] as String)
                : json['completedAt'] as DateTime?)
            : null,
        reward: json['reward'] != null ? (json['reward'] is num ? (json['reward'] as num).toDouble() : null) : null,
        claimedBy: json['claimedBy'] as String?,
        claimStatus: json['claimStatus'] as String?,
        needsApproval: json['needsApproval'] == true || json['needsApproval'] == 'true',
        requiresClaim: json['requiresClaim'] == true || json['requiresClaim'] == 'true',
        approvedBy: json['approvedBy'] as String?,
        approvedAt: json['approvedAt'] != null
            ? (json['approvedAt'] is String
                ? DateTime.parse(json['approvedAt'] as String)
                : json['approvedAt'] as DateTime?)
            : null,
        createdBy: json['createdBy'] as String?,
        isRefunded: json['isRefunded'] == true || json['isRefunded'] == 'true',
        refundReason: json['refundReason'] as String?,
        refundNote: json['refundNote'] as String?,
        refundedAt: json['refundedAt'] != null
            ? (json['refundedAt'] is String
                ? DateTime.parse(json['refundedAt'] as String)
                : json['refundedAt'] as DateTime?)
            : null,
      );
    } catch (e) {
      // If parsing fails completely, return a default task with the ID
      return Task(
        id: json['id'] as String? ?? 'unknown',
        title: json['title'] as String? ?? 'Invalid Task',
        description: json['description'] as String? ?? '',
        isCompleted: false,
        createdAt: DateTime.now(),
      );
    }
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    String? priority,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? completedAt,
    double? reward,
    String? claimedBy,
    String? claimStatus,
    bool? needsApproval,
    bool? requiresClaim,
    String? approvedBy,
    DateTime? approvedAt,
    String? createdBy,
    bool? isRefunded,
    String? refundReason,
    String? refundNote,
    DateTime? refundedAt,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        assignedTo: assignedTo ?? this.assignedTo,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
        reward: reward ?? this.reward,
        claimedBy: claimedBy ?? this.claimedBy,
        claimStatus: claimStatus ?? this.claimStatus,
        needsApproval: needsApproval ?? this.needsApproval,
        requiresClaim: requiresClaim ?? this.requiresClaim,
        approvedBy: approvedBy ?? this.approvedBy,
        approvedAt: approvedAt ?? this.approvedAt,
        createdBy: createdBy ?? this.createdBy,
        isRefunded: isRefunded ?? this.isRefunded,
        refundReason: refundReason ?? this.refundReason,
        refundNote: refundNote ?? this.refundNote,
        refundedAt: refundedAt ?? this.refundedAt,
      );
  
  // Helper getters
  bool get isAwaitingApproval => needsApproval && isCompleted && approvedBy == null;
  bool get isClaimed => claimedBy != null && claimStatus == 'approved';
  bool get hasPendingClaim => claimedBy != null && claimStatus == 'pending';
}

