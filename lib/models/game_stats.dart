/// Model for family game statistics
class GameStats {
  final String userId;
  final String familyId;
  final int winsChess;
  final int winsScramble;
  final int winsBingo;
  final int streakDays;
  final DateTime? lastPlayed;
  final DateTime? lastUpdated;

  GameStats({
    required this.userId,
    required this.familyId,
    this.winsChess = 0,
    this.winsScramble = 0,
    this.winsBingo = 0,
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
        streakDays: streakDays ?? this.streakDays,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

