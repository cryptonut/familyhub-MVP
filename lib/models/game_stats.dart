/// Model for family game statistics
class GameStats {
  final String userId;
  final String familyId;
  final int winsChess;
  final int winsScramble;
  final int winsBingo;
  final int tetrisHighScore; // Highest Tetris score
  final int puzzle2048HighScore; // Highest 2048 score
  final int slidePuzzleBestTime; // Best time in milliseconds for slide puzzle
  final int streakDays;
  final DateTime? lastPlayed;
  final DateTime? lastUpdated;

  GameStats({
    required this.userId,
    required this.familyId,
    this.winsChess = 0,
    this.winsScramble = 0,
    this.winsBingo = 0,
    this.tetrisHighScore = 0,
    this.puzzle2048HighScore = 0,
    this.slidePuzzleBestTime = 0,
    this.streakDays = 0,
    this.lastPlayed,
    this.lastUpdated,
  });

  int get totalWins => winsChess + winsScramble + winsBingo;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'familyId': familyId,
        'winsChess': winsChess,
        'winsScramble': winsScramble,
        'winsBingo': winsBingo,
        'tetrisHighScore': tetrisHighScore,
        'puzzle2048HighScore': puzzle2048HighScore,
        'slidePuzzleBestTime': slidePuzzleBestTime,
        'streakDays': streakDays,
        if (lastPlayed != null) 'lastPlayed': lastPlayed!.toIso8601String(),
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
        userId: json['userId'] as String,
        familyId: json['familyId'] as String,
        winsChess: (json['winsChess'] as num?)?.toInt() ?? 0,
        winsScramble: (json['winsScramble'] as num?)?.toInt() ?? 0,
        winsBingo: (json['winsBingo'] as num?)?.toInt() ?? 0,
        tetrisHighScore: (json['tetrisHighScore'] as num?)?.toInt() ?? 0,
        puzzle2048HighScore: (json['puzzle2048HighScore'] as num?)?.toInt() ?? 0,
        slidePuzzleBestTime: (json['slidePuzzleBestTime'] as num?)?.toInt() ?? 0,
        streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.parse(json['lastPlayed'] as String)
            : null,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : null,
      );

  GameStats copyWith({
    String? userId,
    String? familyId,
    int? winsChess,
    int? winsScramble,
    int? winsBingo,
    int? tetrisHighScore,
    int? puzzle2048HighScore,
    int? slidePuzzleBestTime,
    int? streakDays,
    DateTime? lastPlayed,
    DateTime? lastUpdated,
  }) =>
      GameStats(
        userId: userId ?? this.userId,
        familyId: familyId ?? this.familyId,
        winsChess: winsChess ?? this.winsChess,
        winsScramble: winsScramble ?? this.winsScramble,
        winsBingo: winsBingo ?? this.winsBingo,
        tetrisHighScore: tetrisHighScore ?? this.tetrisHighScore,
        puzzle2048HighScore: puzzle2048HighScore ?? this.puzzle2048HighScore,
        slidePuzzleBestTime: slidePuzzleBestTime ?? this.slidePuzzleBestTime,
        streakDays: streakDays ?? this.streakDays,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

