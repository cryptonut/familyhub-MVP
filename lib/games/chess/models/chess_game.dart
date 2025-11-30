import 'chess_move.dart';

/// Model representing a chess game
class ChessGame {
  final String id;
  final String whitePlayerId;
  final String? blackPlayerId; // null for AI games
  final String? whitePlayerName;
  final String? blackPlayerName;
  final GameMode mode; // solo, family, open
  final GameStatus status; // waiting, active, finished
  final String? winnerId; // null for draw
  final String? familyId; // for family games
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String fen; // current position
  final List<ChessMove> moves;
  final int whiteTimeRemaining; // milliseconds
  final int blackTimeRemaining; // milliseconds
  final bool isWhiteTurn;
  final String? lastMove; // last move in UCI format
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final String? enPassantSquare; // square available for en passant
  final int halfmoveClock; // for 50-move rule
  final int fullmoveNumber;
  final GameResult? result; // win, loss, draw, null if ongoing
  final String? resultReason; // checkmate, stalemate, resignation, timeout, etc.
  final List<String> spectators; // user IDs watching the game
  final Map<String, dynamic>? metadata; // AI difficulty, etc.
  final String? invitedPlayerId; // For family games: the player who was invited (but hasn't joined yet)

  ChessGame({
    required this.id,
    required this.whitePlayerId,
    this.blackPlayerId,
    this.whitePlayerName,
    this.blackPlayerName,
    required this.mode,
    required this.status,
    this.winnerId,
    this.familyId,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    required this.fen,
    required this.moves,
    required this.whiteTimeRemaining,
    required this.blackTimeRemaining,
    required this.isWhiteTurn,
    this.lastMove,
    required this.whiteCanCastleKingside,
    required this.whiteCanCastleQueenside,
    required this.blackCanCastleKingside,
    required this.blackCanCastleQueenside,
    this.enPassantSquare,
    required this.halfmoveClock,
    required this.fullmoveNumber,
    this.result,
    this.resultReason,
    List<String>? spectators,
    this.metadata,
    this.invitedPlayerId,
  }) : spectators = spectators ?? [];

  /// Create a new game
  factory ChessGame.newGame({
    required String id,
    required String whitePlayerId,
    String? blackPlayerId,
    String? whitePlayerName,
    String? blackPlayerName,
    required GameMode mode,
    String? familyId,
    int initialTimeMs = 600000, // 10 minutes default
    Map<String, dynamic>? metadata,
    String? invitedPlayerId, // For family games: intended opponent who hasn't joined yet
  }) {
    // For family games, if blackPlayerId is provided but we also have invitedPlayerId,
    // it means the opponent was invited but hasn't joined - keep status as waiting
    final shouldBeActive = blackPlayerId != null && 
                          (mode != GameMode.family || invitedPlayerId == null);
    
    return ChessGame(
      id: id,
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      whitePlayerName: whitePlayerName,
      blackPlayerName: blackPlayerName,
      mode: mode,
      status: shouldBeActive ? GameStatus.active : GameStatus.waiting,
      familyId: familyId,
      createdAt: DateTime.now(),
      startedAt: shouldBeActive ? DateTime.now() : null,
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: [],
      whiteTimeRemaining: initialTimeMs,
      blackTimeRemaining: initialTimeMs,
      isWhiteTurn: true,
      whiteCanCastleKingside: true,
      whiteCanCastleQueenside: true,
      blackCanCastleKingside: true,
      blackCanCastleQueenside: true,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      metadata: metadata,
      invitedPlayerId: invitedPlayerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'whitePlayerId': whitePlayerId,
        'blackPlayerId': blackPlayerId,
        'whitePlayerName': whitePlayerName,
        'blackPlayerName': blackPlayerName,
        'mode': mode.name,
        'status': status.name,
        'winnerId': winnerId,
        'familyId': familyId,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'fen': fen,
        'moves': moves.map((m) => m.toJson()).toList(),
        'whiteTimeRemaining': whiteTimeRemaining,
        'blackTimeRemaining': blackTimeRemaining,
        'isWhiteTurn': isWhiteTurn,
        'lastMove': lastMove,
        'whiteCanCastleKingside': whiteCanCastleKingside,
        'whiteCanCastleQueenside': whiteCanCastleQueenside,
        'blackCanCastleKingside': blackCanCastleKingside,
        'blackCanCastleQueenside': blackCanCastleQueenside,
        'enPassantSquare': enPassantSquare,
        'halfmoveClock': halfmoveClock,
        'fullmoveNumber': fullmoveNumber,
        'result': result?.name,
        'resultReason': resultReason,
        'spectators': spectators,
        'metadata': metadata,
        'invitedPlayerId': invitedPlayerId,
      };

  factory ChessGame.fromJson(Map<String, dynamic> json) {
    return ChessGame(
      id: json['id'] as String,
      whitePlayerId: json['whitePlayerId'] as String,
      blackPlayerId: json['blackPlayerId'] as String?,
      whitePlayerName: json['whitePlayerName'] as String?,
      blackPlayerName: json['blackPlayerName'] as String?,
      mode: GameMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => GameMode.solo,
      ),
      status: GameStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameStatus.waiting,
      ),
      winnerId: json['winnerId'] as String?,
      familyId: json['familyId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      fen: json['fen'] as String,
      moves: (json['moves'] as List<dynamic>?)
              ?.map((m) => ChessMove.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      whiteTimeRemaining: (json['whiteTimeRemaining'] as num?)?.toInt() ?? 600000,
      blackTimeRemaining: (json['blackTimeRemaining'] as num?)?.toInt() ?? 600000,
      isWhiteTurn: json['isWhiteTurn'] as bool? ?? true,
      lastMove: json['lastMove'] as String?,
      whiteCanCastleKingside: json['whiteCanCastleKingside'] as bool? ?? true,
      whiteCanCastleQueenside: json['whiteCanCastleQueenside'] as bool? ?? true,
      blackCanCastleKingside: json['blackCanCastleKingside'] as bool? ?? true,
      blackCanCastleQueenside: json['blackCanCastleQueenside'] as bool? ?? true,
      enPassantSquare: json['enPassantSquare'] as String?,
      halfmoveClock: (json['halfmoveClock'] as num?)?.toInt() ?? 0,
      fullmoveNumber: (json['fullmoveNumber'] as num?)?.toInt() ?? 1,
      result: json['result'] != null
          ? GameResult.values.firstWhere(
              (e) => e.name == json['result'],
              orElse: () => GameResult.draw,
            )
          : null,
      resultReason: json['resultReason'] as String?,
      spectators: (json['spectators'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      invitedPlayerId: json['invitedPlayerId'] as String?,
    );
  }

  ChessGame copyWith({
    String? id,
    String? whitePlayerId,
    String? blackPlayerId,
    String? whitePlayerName,
    String? blackPlayerName,
    GameMode? mode,
    GameStatus? status,
    String? winnerId,
    String? familyId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? fen,
    List<ChessMove>? moves,
    int? whiteTimeRemaining,
    int? blackTimeRemaining,
    bool? isWhiteTurn,
    String? lastMove,
    bool? whiteCanCastleKingside,
    bool? whiteCanCastleQueenside,
    bool? blackCanCastleKingside,
    bool? blackCanCastleQueenside,
    String? enPassantSquare,
    int? halfmoveClock,
    int? fullmoveNumber,
    GameResult? result,
    String? resultReason,
    List<String>? spectators,
    Map<String, dynamic>? metadata,
    String? invitedPlayerId,
  }) {
    return ChessGame(
      id: id ?? this.id,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      whitePlayerName: whitePlayerName ?? this.whitePlayerName,
      blackPlayerName: blackPlayerName ?? this.blackPlayerName,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      winnerId: winnerId ?? this.winnerId,
      familyId: familyId ?? this.familyId,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      whiteTimeRemaining: whiteTimeRemaining ?? this.whiteTimeRemaining,
      blackTimeRemaining: blackTimeRemaining ?? this.blackTimeRemaining,
      isWhiteTurn: isWhiteTurn ?? this.isWhiteTurn,
      lastMove: lastMove ?? this.lastMove,
      whiteCanCastleKingside: whiteCanCastleKingside ?? this.whiteCanCastleKingside,
      whiteCanCastleQueenside: whiteCanCastleQueenside ?? this.whiteCanCastleQueenside,
      blackCanCastleKingside: blackCanCastleKingside ?? this.blackCanCastleKingside,
      blackCanCastleQueenside: blackCanCastleQueenside ?? this.blackCanCastleQueenside,
      enPassantSquare: enPassantSquare ?? this.enPassantSquare,
      halfmoveClock: halfmoveClock ?? this.halfmoveClock,
      fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
      result: result ?? this.result,
      resultReason: resultReason ?? this.resultReason,
      spectators: spectators ?? this.spectators,
      metadata: metadata ?? this.metadata,
      invitedPlayerId: invitedPlayerId ?? this.invitedPlayerId,
    );
  }

  /// Check if a user is a player in this game
  bool isPlayer(String userId) {
    return whitePlayerId == userId || blackPlayerId == userId;
  }

  /// Get the color of a player
  bool? isPlayerWhite(String userId) {
    if (whitePlayerId == userId) return true;
    if (blackPlayerId == userId) return false;
    return null;
  }

  /// Check if it's a user's turn
  bool isMyTurn(String userId) {
    if (whitePlayerId == userId) return isWhiteTurn;
    if (blackPlayerId == userId) return !isWhiteTurn;
    return false;
  }
}

enum GameMode {
  solo, // vs AI
  family, // vs family member
  open, // vs random player
}

enum GameStatus {
  waiting, // waiting for opponent
  active, // game in progress
  finished, // game ended
}

enum GameResult {
  whiteWin,
  blackWin,
  draw,
}

