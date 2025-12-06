import 'package:chess/chess.dart' as chess_lib;
import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../../../core/services/logger_service.dart';
import '../models/chess_move.dart';
import '../utils/chess_move_validator.dart';
import 'chess_service.dart';

/// Parameters for AI computation in isolate
class _AIComputeParams {
  final String fen;
  final String difficultyName;
  
  _AIComputeParams(this.fen, this.difficultyName);
}

/// Service for AI chess opponent
class ChessAIService {
  final Random _random = Random();

  /// Get the best move for the AI
  /// Uses Flutter's compute() to run on a separate isolate for hard difficulty
  Future<ChessMove> getBestMove({
    required chess_lib.Chess game,
    required AIDifficulty difficulty,
  }) async {
    try {
      // For hard difficulty, use isolate to prevent UI freezing
      if (difficulty == AIDifficulty.hard) {
        return await _getHardMoveAsync(game);
      }
      
      switch (difficulty) {
        case AIDifficulty.easy:
          return _getRandomMove(game);
        case AIDifficulty.medium:
          return _getMediumMove(game);
        case AIDifficulty.hard:
          return _getHardMove(game); // Fallback
      }
    } catch (e, st) {
      Logger.error('Error getting AI move', error: e, stackTrace: st, tag: 'ChessAIService');
      // Fallback to random move
      return _getRandomMove(game);
    }
  }
  
  /// Run hard AI calculation in isolate
  Future<ChessMove> _getHardMoveAsync(chess_lib.Chess game) async {
    try {
      final params = _AIComputeParams(game.fen, 'hard');
      final result = await compute(_computeHardMove, params);
      return ChessMove.fromUCI(result);
    } catch (e) {
      Logger.warning('Isolate computation failed, falling back to main thread', error: e, tag: 'ChessAIService');
      return _getHardMove(game);
    }
  }
  
  /// Static function for isolate computation
  static String _computeHardMove(_AIComputeParams params) {
    final game = chess_lib.Chess();
    game.load(params.fen);
    
    final moves = _generateAllValidMovesStatic(game);
    if (moves.isEmpty) {
      throw Exception('No valid moves available');
    }

    int bestScore = -9999;
    Map<String, dynamic>? bestMove;

    for (var move in moves) {
      final testGame = chess_lib.Chess();
      testGame.load(game.fen);
      final testFen = _executeMoveStatic(testGame, move['from'] as String, move['to'] as String);
      if (testFen == null) continue;

      final score = _minimaxStatic(testGame, 3, false, -9999, 9999);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    final from = (bestMove ?? moves[0])['from'] as String;
    final to = (bestMove ?? moves[0])['to'] as String;
    final promotion = (bestMove ?? moves[0])['promotion'] as String?;
    return promotion != null ? '$from$to$promotion' : '$from$to';
  }
  
  /// Static version of generateAllValidMoves for isolate
  static List<Map<String, dynamic>> _generateAllValidMovesStatic(chess_lib.Chess game) {
    final validMoves = <Map<String, dynamic>>[];
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];
    final currentTurn = game.turn;
    
    for (final file in files) {
      for (final rank in ranks) {
        final fromSquare = '$file$rank';
        final piece = game.get(fromSquare);
        
        if (piece == null || piece.color != currentTurn) continue;
        
        for (final destFile in files) {
          for (final destRank in ranks) {
            final toSquare = '$destFile$destRank';
            if (toSquare == fromSquare) continue;
            
            if (_isValidMoveStatic(game, fromSquare, toSquare)) {
              final destPiece = game.get(toSquare);
              validMoves.add({
                'from': fromSquare,
                'to': toSquare,
                'piece': piece.type,
                'color': piece.color,
                'captured': destPiece?.type,
                'promotion': null,
              });
            }
          }
        }
      }
    }
    
    return validMoves;
  }
  
  /// Static version of isValidMove for isolate
  static bool _isValidMoveStatic(chess_lib.Chess game, String from, String to) {
    try {
      final testGame = chess_lib.Chess();
      testGame.load(game.fen);
      
      final originalFen = testGame.fen;
      final moveResult = testGame.move({'from': from, 'to': to});
      if (moveResult == null) return false;
      
      final newFen = testGame.fen;
      if (newFen == originalFen) return false;
      
      final originalPiece = game.get(from);
      if (originalPiece == null || originalPiece.color != game.turn) return false;
      
      final turnChanged = testGame.turn != game.turn;
      if (!turnChanged) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Static version of executeMove for isolate
  static String? _executeMoveStatic(chess_lib.Chess game, String from, String to) {
    try {
      final originalFen = game.fen;
      final moveResult = game.move({'from': from, 'to': to});
      
      if (moveResult == null) return null;
      
      final newFen = game.fen;
      if (newFen == originalFen) return null;
      
      return newFen;
    } catch (e) {
      return null;
    }
  }
  
  /// Static version of minimax for isolate
  static int _minimaxStatic(chess_lib.Chess game, int depth, bool isMaximizing, int alpha, int beta) {
    if (depth == 0 || game.game_over) {
      return _evaluatePositionStatic(game);
    }

    final moves = _generateAllValidMovesStatic(game);
    if (moves.isEmpty) {
      return _evaluatePositionStatic(game);
    }

    if (isMaximizing) {
      int maxEval = -9999;
      for (var move in moves) {
        final testGame = chess_lib.Chess();
        testGame.load(game.fen);
        final testFen = _executeMoveStatic(testGame, move['from'] as String, move['to'] as String);
        if (testFen == null) continue;
        final eval = _minimaxStatic(testGame, depth - 1, false, alpha, beta);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      int minEval = 9999;
      for (var move in moves) {
        final testGame = chess_lib.Chess();
        testGame.load(game.fen);
        final testFen = _executeMoveStatic(testGame, move['from'] as String, move['to'] as String);
        if (testFen == null) continue;
        final eval = _minimaxStatic(testGame, depth - 1, true, alpha, beta);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }
  
  /// Static version of evaluatePosition for isolate
  static int _evaluatePositionStatic(chess_lib.Chess game) {
    if (game.in_checkmate) {
      return game.turn == chess_lib.Color.WHITE ? -1000 : 1000;
    }
    if (game.in_stalemate || game.in_draw) {
      return 0;
    }

    int score = 0;
    final board = game.board;

    for (int i = 0; i < 64; i++) {
      final piece = board[i];
      if (piece != null) {
        final value = _getPieceValueStatic(piece.type);
        score += piece.color == chess_lib.Color.WHITE ? value : -value;
      }
    }

    return score;
  }
  
  /// Static version of getPieceValue for isolate
  static int _getPieceValueStatic(chess_lib.PieceType type) {
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

