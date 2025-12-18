/// Leaderboard entry model
class LeaderboardEntry {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final int totalScore;
  final int booksCompleted;
  final double averageScore;
  final LeaderboardScope scope; // family, hub, global
  final int rank; // Position on leaderboard

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.totalScore,
    required this.booksCompleted,
    required this.averageScore,
    required this.scope,
    required this.rank,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'totalScore': totalScore,
        'booksCompleted': booksCompleted,
        'averageScore': averageScore,
        'scope': scope.name,
        'rank': rank,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      totalScore: (json['totalScore'] as num).toInt(),
      booksCompleted: (json['booksCompleted'] as num).toInt(),
      averageScore: (json['averageScore'] as num).toDouble(),
      scope: LeaderboardScope.values.firstWhere(
        (e) => e.name == json['scope'],
        orElse: () => LeaderboardScope.family,
      ),
      rank: (json['rank'] as num).toInt(),
    );
  }

  LeaderboardEntry copyWith({
    String? userId,
    String? userName,
    String? userPhotoUrl,
    int? totalScore,
    int? booksCompleted,
    double? averageScore,
    LeaderboardScope? scope,
    int? rank,
  }) =>
      LeaderboardEntry(
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
        totalScore: totalScore ?? this.totalScore,
        booksCompleted: booksCompleted ?? this.booksCompleted,
        averageScore: averageScore ?? this.averageScore,
        scope: scope ?? this.scope,
        rank: rank ?? this.rank,
      );
}


/// Leaderboard scope enum
enum LeaderboardScope {
  family,
  hub,
  global,
}

