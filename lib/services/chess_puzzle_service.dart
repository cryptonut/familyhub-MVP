import 'package:chess/chess.dart' as chess_lib;
import 'dart:math';
import '../core/services/logger_service.dart';

/// Service for generating and managing chess puzzles
class ChessPuzzleService {
  final Random _random = Random();

  /// Convert square name (e.g., "e2") to square index
  int _squareToIndex(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return rank * 8 + file;
  }

  /// Convert square index to square name (e.g., "e2")
  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = (index ~/ 8) + 1;
    return '$file$rank';
  }

  /// Pre-defined chess puzzles (FEN positions with solutions)
  final List<Map<String, dynamic>> _puzzles = [
    {
      'fen': 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
      'solution': 'Bxf7+',
      'hint': 'Look for a fork or discovered attack',
      'description': 'Fork the king and rook',
    },
    {
      'fen': 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
      'solution': 'Bxf7+',
      'hint': 'Sacrifice the bishop for a winning position',
      'description': 'Bishop sacrifice',
    },
    {
      'fen': 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
      'solution': 'Qh4#',
      'hint': 'Checkmate in one move',
      'description': 'Scholar\'s mate',
    },
    {
      'fen': 'r1bqkb1r/pppp1Qpp/2n2n2/2B1p3/4P3/8/PPPP1PPP/RNBQK2R b KQkq - 0 4',
      'solution': 'Qxf7#',
      'hint': 'The queen can deliver checkmate',
      'description': 'Quick checkmate',
    },
    {
      'fen': 'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
      'solution': 'Nxe5',
      'hint': 'Capture the central pawn',
      'description': 'Central pawn capture',
    },
  ];

  /// Get a random puzzle
  Map<String, dynamic> getRandomPuzzle() {
    return _puzzles[_random.nextInt(_puzzles.length)];
  }

  /// Create a chess game from FEN
  chess_lib.Chess createGameFromFEN(String fen) {
    final game = chess_lib.Chess();
    game.load(fen);
    return game;
  }

  /// Validate a move in SAN (Standard Algebraic Notation) or UCI format
  bool isValidMove(chess_lib.Chess game, String move) {
    try {
      // Try UCI format (e.g., "e2e4")
      if (move.length == 4 || move.length == 5) {
        final fromSquare = move.substring(0, 2);
        final toSquare = move.substring(2, 4);
        final fromIndex = _squareToIndex(fromSquare);
        final toIndex = _squareToIndex(toSquare);
        
        final moves = game.generate_moves({'verbose': true});
        for (var m in moves) {
          if (m.from == fromIndex && m.to == toIndex) {
            // Check promotion if specified
            if (move.length == 5) {
              // Promotion piece specified
              final promotionChar = move[4].toLowerCase();
              final promotionMap = {
                'q': chess_lib.PieceType.QUEEN,
                'r': chess_lib.PieceType.ROOK,
                'b': chess_lib.PieceType.BISHOP,
                'n': chess_lib.PieceType.KNIGHT,
              };
              final expectedPromotion = promotionMap[promotionChar];
              if (expectedPromotion != null && m.promotion == expectedPromotion) {
                return true;
              }
            } else if (m.promotion == null) {
              // No promotion specified and move has no promotion
              return true;
            }
          }
        }
      }
      
      // Try SAN format (e.g., "Nf3", "e4")
      try {
        game.move(move);
        game.undo();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check if a move matches the solution
  bool isSolution(chess_lib.Chess game, String move, String solution) {
    try {
      // Normalize solution (remove +, #, =, etc. for comparison)
      final normalizedSolution = solution
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[+#=]'), '');

      // If move is in UCI format (e.g., "e2e4"), try to make it and get SAN
      if (move.length == 4 || move.length == 5) {
        final fromSquare = move.substring(0, 2);
        final toSquare = move.substring(2, 4);
        final fromIndex = _squareToIndex(fromSquare);
        final toIndex = _squareToIndex(toSquare);
        
        // Find the move in the list of valid moves and try to make it
        final moves = game.generate_moves({'verbose': true});
        for (var m in moves) {
          if (m.from == fromIndex && m.to == toIndex) {
            // Check promotion if specified
            bool promotionMatches = true;
            if (move.length == 5) {
              final promotionChar = move[4].toLowerCase();
              final promotionMap = {
                'q': chess_lib.PieceType.QUEEN,
                'r': chess_lib.PieceType.ROOK,
                'b': chess_lib.PieceType.BISHOP,
                'n': chess_lib.PieceType.KNIGHT,
              };
              final expectedPromotion = promotionMap[promotionChar];
              promotionMatches = expectedPromotion != null && m.promotion == expectedPromotion;
            } else {
              promotionMatches = m.promotion == null;
            }
            
            if (promotionMatches) {
              // Make the move and check if it matches the solution
              // We'll compare by trying the solution move and seeing if positions match
              try {
                final moveUci = '$fromSquare$toSquare${move.length == 5 ? move[4] : ''}';
                game.move(moveUci);
                final positionAfterMove = game.fen;
                game.undo();
                
                // Now try the solution move
                game.move(solution);
                final positionAfterSolution = game.fen;
                game.undo();
                
                // If positions match, the moves are equivalent
                if (positionAfterMove == positionAfterSolution) {
                  return true;
                }
              } catch (e) {
                // Move failed, continue
              }
            }
          }
        }
      } else {
        // Move is already in SAN format
        final normalizedMove = move
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[+#=]'), '');
        if (normalizedMove == normalizedSolution) {
          return true;
        }
      }

      return false;
    } catch (e) {
      Logger.error('Error checking solution', error: e, tag: 'ChessPuzzleService');
      return false;
    }
  }

  /// Get the best move hint (simplified - just returns a valid move)
  String getHint(chess_lib.Chess game) {
    final moves = game.generate_moves({'verbose': true});
    if (moves.isEmpty) return 'No moves available';
    
    final move = moves[0];
    final fromSquare = _indexToSquare(move.from);
    final toSquare = _indexToSquare(move.to);
    return '$fromSquare$toSquare';
  }
}

