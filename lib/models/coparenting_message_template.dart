/// Message template for co-parenting communication
class CoparentingMessageTemplate {
  final String id;
  final String hubId;
  final String title;
  final String content;
  final MessageCategory category;
  final DateTime createdAt;
  final String createdBy;
  final bool isDefault; // System default templates

  CoparentingMessageTemplate({
    required this.id,
    required this.hubId,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.createdBy,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'title': title,
        'content': content,
        'category': category.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'isDefault': isDefault,
      };

  factory CoparentingMessageTemplate.fromJson(Map<String, dynamic> json) =>
      CoparentingMessageTemplate(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        category: MessageCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => MessageCategory.general,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        isDefault: (json['isDefault'] as bool?) ?? false,
      );
}

enum MessageCategory {
  schedule, // Schedule-related messages
  expense, // Expense-related messages
  emergency, // Emergency/urgent messages
  childInfo, // Child information updates
  general, // General communication
}

extension MessageCategoryExtension on MessageCategory {
  String get displayName {
    switch (this) {
      case MessageCategory.schedule:
        return 'Schedule';
      case MessageCategory.expense:
        return 'Expense';
      case MessageCategory.emergency:
        return 'Emergency';
      case MessageCategory.childInfo:
        return 'Child Info';
      case MessageCategory.general:
        return 'General';
    }
  }
}

