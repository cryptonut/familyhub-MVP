import 'package:cloud_firestore/cloud_firestore.dart';

/// Book model representing a book from Open Library or other sources
class Book {
  final String id; // Open Library ID (OLID) or custom ID
  final String title;
  final List<String> authors;
  final String? description;
  final DateTime? publishDate;
  final String? coverUrl;
  final int? pageCount;
  final String? isbn;
  final double? averageRating; // Calculated from ratings
  final int ratingCount; // Number of ratings
  final String? olid; // Open Library ID if from Open Library
  final DateTime? addedAt; // When book was added to hub
  final String? addedBy; // User ID who added the book

  Book({
    required this.id,
    required this.title,
    required this.authors,
    this.description,
    this.publishDate,
    this.coverUrl,
    this.pageCount,
    this.isbn,
    this.averageRating,
    this.ratingCount = 0,
    this.olid,
    this.addedAt,
    this.addedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'description': description,
        'publishDate': publishDate?.toIso8601String(),
        'coverUrl': coverUrl,
        'pageCount': pageCount,
        'isbn': isbn,
        'averageRating': averageRating,
        'ratingCount': ratingCount,
        'olid': olid,
        'addedAt': addedAt?.toIso8601String(),
        'addedBy': addedBy,
      };

  factory Book.fromJson(Map<String, dynamic> json) {
    DateTime? publishDate;
    if (json['publishDate'] != null) {
      if (json['publishDate'] is Timestamp) {
        publishDate = (json['publishDate'] as Timestamp).toDate();
      } else if (json['publishDate'] is String) {
        publishDate = DateTime.tryParse(json['publishDate'] as String);
      }
    }

    DateTime? addedAt;
    if (json['addedAt'] != null) {
      if (json['addedAt'] is Timestamp) {
        addedAt = (json['addedAt'] as Timestamp).toDate();
      } else if (json['addedAt'] is String) {
        addedAt = DateTime.tryParse(json['addedAt'] as String);
      }
    }

    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      authors: List<String>.from(json['authors'] as List? ?? []),
      description: json['description'] as String?,
      publishDate: publishDate,
      coverUrl: json['coverUrl'] as String?,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      isbn: json['isbn'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as int?) ?? 0,
      olid: json['olid'] as String?,
      addedAt: addedAt,
      addedBy: json['addedBy'] as String?,
    );
  }

  Book copyWith({
    String? id,
    String? title,
    List<String>? authors,
    String? description,
    DateTime? publishDate,
    String? coverUrl,
    int? pageCount,
    String? isbn,
    double? averageRating,
    int? ratingCount,
    String? olid,
    DateTime? addedAt,
    String? addedBy,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        authors: authors ?? this.authors,
        description: description ?? this.description,
        publishDate: publishDate ?? this.publishDate,
        coverUrl: coverUrl ?? this.coverUrl,
        pageCount: pageCount ?? this.pageCount,
        isbn: isbn ?? this.isbn,
        averageRating: averageRating ?? this.averageRating,
        ratingCount: ratingCount ?? this.ratingCount,
        olid: olid ?? this.olid,
        addedAt: addedAt ?? this.addedAt,
        addedBy: addedBy ?? this.addedBy,
      );
}


