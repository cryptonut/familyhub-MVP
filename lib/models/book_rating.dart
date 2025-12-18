import 'package:cloud_firestore/cloud_firestore.dart';

/// Book rating and comment model
class BookRating {
  final String id;
  final String bookId;
  final String userId;
  final String? userName; // null if anonymous
  final int rating; // 1-5
  final String? comment;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookRating({
    required this.id,
    required this.bookId,
    required this.userId,
    this.userName,
    required this.rating,
    this.comment,
    this.isAnonymous = false,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'userId': userId,
        'userName': isAnonymous ? null : userName,
        'rating': rating,
        'comment': comment,
        'isAnonymous': isAnonymous,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory BookRating.fromJson(Map<String, dynamic> json) {
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
        updatedAt = DateTime.tryParse(json['updatedAt'] as String);
      }
    }

    return BookRating(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 1,
      comment: json['comment'] as String?,
      isAnonymous: (json['isAnonymous'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  BookRating copyWith({
    String? id,
    String? bookId,
    String? userId,
    String? userName,
    int? rating,
    String? comment,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BookRating(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        isAnonymous: isAnonymous ?? this.isAnonymous,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}


