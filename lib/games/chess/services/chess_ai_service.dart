import 'package:chess/chess.dart' as chess_lib;
import 'dart:math';
import '../../../core/services/logger_service.dart';
import '../models/chess_move.dart';
import '../utils/chess_move_validator.dart';
import 'chess_service.dart';

/// Service for AI chess opponent
class ChessAIService {
  final Random _random = Random();

  /// Get the best move for the AI
  Future<ChessMove> getBestMove({
    required chess_lib.Chess game,
    required AIDifficulty difficulty,
  }) async {
    try {
      switch (difficulty) {
        case AIDifficulty.easy:
          return _getRandomMove(game);
        case AIDifficulty.medium:
          return _getMediumMove(game);
        case AIDifficulty.hard:
          return _getHardMove(game);
      }
    } catch (e, st) {
      Logger.error('Error getting AI move', error: e, stackTrace: st, tag: 'ChessAIService');
      // Fallback to random move
      return _getRandomMove(game);
    }
  }

  /// Easy: Random valid move
  ChessMove _getRandomMove(chess_lib.Chess game) {
    final moves = ChessMoveValidator.generateAllValidMoves(game);
    if (moves.isEmpty) {
      throw Exception('No valid moves available');
    }
    final move = moves[_random.nextInt(moves.length)];
    return _mapToChessMove(move);
  }

  /// Medium: Prefer captures and center control
  ChessMove _getMediumMove(chess_lib.Chess game) {
    final moves = ChessMoveValidator.generateAllValidMoves(game);
    if (moves.isEmpty) {
      throw Exception('No valid moves available');
    }

    // Score moves
    final scoredMoves = moves.map((move) {
      int score = 0;

      // Prefer captures
      if (move['captured'] != null) {
        score += _getPieceValue(move['captured'] as chess_lib.PieceType) * 10;
      }

      // Prefer center squares
      final centerSquares = ['e4', 'e5', 'd4', 'd5'];
      if (centerSquares.contains(move['to'])) {
        score += 5;
      }

      // Prefer developing pieces (knights and bishops)
      final pieceType = move['piece'] as chess_lib.PieceType;
      if (pieceType == chess_lib.PieceType.KNIGHT || pieceType == chess_lib.PieceType.BISHOP) {
        score += 2;
      }

      // Prefer checks
      final testGame = chess_lib.Chess();
      testGame.load(game.fen);
      final testFen = ChessMoveValidator.executeMove(testGame, move['from'] as String, move['to'] as String);
      if (testFen != null && testGame.in_check) {
        score += 5;
      }

      return {'move': move, 'score': score};
    }).toList();

    // Sort by score and pick from top moves (with some randomness)
    scoredMoves.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final topMoves = scoredMoves.take(3).toList();
    final selected = topMoves[_random.nextInt(topMoves.length)];
    return _mapToChessMove(selected['move'] as Map<String, dynamic>);
  }

  /// Hard: Minimax algorithm with alpha-beta pruning
  ChessMove _getHardMove(chess_lib.Chess game) {
    final moves = ChessMoveValidator.generateAllValidMoves(game);
    if (moves.isEmpty) {
      throw Exception('No valid moves available');
    }

    int bestScore = -9999;
    Map<String, dynamic>? bestMove;

    for (var move in moves) {
      final testGame = chess_lib.Chess();
      testGame.load(game.fen);
      final testFen = ChessMoveValidator.executeMove(testGame, move['from'] as String, move['to'] as String);
      if (testFen == null) continue;

      final score = _minimax(testGame, 3, false, -9999, 9999);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return _mapToChessMove(bestMove ?? moves[0]);
  }

  /// Minimax algorithm with alpha-beta pruning
  int _minimax(chess_lib.Chess game, int depth, bool isMaximizing, int alpha, int beta) {
    if (depth == 0 || game.game_over) {
      return _evaluatePosition(game);
    }

    final moves = ChessMoveValidator.generateAllValidMoves(game);
    if (moves.isEmpty) {
      return _evaluatePosition(game);
    }

    if (isMaximizing) {
      int maxEval = -9999;
      for (var move in moves) {
        final testGame = chess_lib.Chess();
        testGame.load(game.fen);
        final testFen = ChessMoveValidator.executeMove(testGame, move['from'] as String, move['to'] as String);
        if (testFen == null) continue;
        final eval = _minimax(testGame, depth - 1, false, alpha, beta);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break; // Alpha-beta pruning
      }
      return maxEval;
    } else {
      int minEval = 9999;
      for (var move in moves) {
        final testGame = chess_lib.Chess();
        testGame.load(game.fen);
        final testFen = ChessMoveValidator.executeMove(testGame, move['from'] as String, move['to'] as String);
        if (testFen == null) continue;
        final eval = _minimax(testGame, depth - 1, true, alpha, beta);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break; // Alpha-beta pruning
      }
      return minEval;
    }
  }

  /// Evaluate position (positive for white, negative for black)
  int _evaluatePosition(chess_lib.Chess game) {
    if (game.in_checkmate) {
      return game.turn == chess_lib.Color.WHITE ? -1000 : 1000;
    }
    if (game.in_stalemate || game.in_draw) {
      return 0;
    }

    int score = 0;
    final board = game.board;

    // Piece values
    for (int i = 0; i < 64; i++) {
      final piece = board[i];
      if (piece != null) {
        final value = _getPieceValue(piece.type);
        score += piece.color == chess_lib.Color.WHITE ? value : -value;
      }
    }

    // Position bonuses (center control, piece development)
    // Simplified evaluation
    return score;
  }

  /// Get piece value
  int _getPieceValue(chess_lib.PieceType type) {
    switch (type) {
      case chess_lib.PieceType.PAWN:
        return 1;
      case chess_lib.PieceType.KNIGHT:
        return 3;
      case chess_lib.PieceType.BISHOP:
        return 3;
      case chess_lib.PieceType.ROOK:
        return 5;
      case chess_lib.PieceType.QUEEN:
        return 9;
      case chess_lib.PieceType.KING:
        return 100;
      default:
        return 0;
    }
  }

  /// Convert chess_lib.Move to ChessMove
  ChessMove _moveToChessMove(chess_lib.Move move) {
    final from = _indexToSquare(move.from);
    final to = _indexToSquare(move.to);
    String? promotion;
    if (move.promotion != null) {
      switch (move.promotion) {
        case chess_lib.PieceType.QUEEN:
          promotion = 'q';
          break;
        case chess_lib.PieceType.ROOK:
          promotion = 'r';
          break;
        case chess_lib.PieceType.BISHOP:
          promotion = 'b';
          break;
        case chess_lib.PieceType.KNIGHT:
          promotion = 'n';
          break;
        default:
          promotion = null;
      }
    }
    final uci = promotion != null ? '$from$to$promotion' : '$from$to';
    return ChessMove.fromUCI(uci);
  }
  
  /// Convert map format to ChessMove
  ChessMove _mapToChessMove(Map<String, dynamic> move) {
    final from = move['from'] as String;
    final to = move['to'] as String;
    final promotion = move['promotion'] as String?;
    final uci = promotion != null ? '$from$to$promotion' : '$from$to';
    return ChessMove.fromUCI(uci);
  }

  /// Convert 0x88 index to square name
  /// The chess library uses 0x88 format where:
  /// - file = index & 0x0F (lower 4 bits)
  /// - rank = index >> 4 (upper 4 bits)
  String _indexToSquare(int index) {
    final file = index & 0x0F; // Lower 4 bits
    final rank = index >> 4; // Upper 4 bits
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    return '$fileChar${rank + 1}';
  }
}

