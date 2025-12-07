import 'package:chess/chess.dart' as chess_lib;
import '../../../core/services/logger_service.dart';

/// Custom move validator that actually works
/// The chess library's move() accepts invalid moves, so we validate manually
class ChessMoveValidator {
  /// Get valid moves for a square by actually validating each possible move
  static List<String> getValidMoves(chess_lib.Chess game, String fromSquare) {
    try {
      final piece = game.get(fromSquare);
      if (piece == null) return [];
      
      final currentTurn = game.turn;
      if (piece.color != currentTurn) return [];
      
      final validMoves = <String>[];
      final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      final ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];
      
      for (final file in files) {
        for (final rank in ranks) {
          final toSquare = '$file$rank';
          if (toSquare == fromSquare) continue;
          
          // Validate the move properly
          if (_isValidMove(game, fromSquare, toSquare)) {
            validMoves.add(toSquare);
          }
        }
      }
      
      Logger.debug('ChessMoveValidator: Found ${validMoves.length} valid moves from $fromSquare: $validMoves', tag: 'ChessMoveValidator');
      return validMoves;
    } catch (e, stackTrace) {
      Logger.error('Error getting valid moves', error: e, stackTrace: stackTrace, tag: 'ChessMoveValidator');
      return [];
    }
  }
  
  /// Validate if a move is legal by:
  /// 1. Creating a copy of the game
  /// 2. Attempting the move
  /// 3. Checking if the FEN actually changed
  /// 4. The chess library's move() already validates that moves don't leave own king in check
  static bool _isValidMove(chess_lib.Chess game, String from, String to) {
    try {
      // Basic validation: check piece exists and is correct color
      final piece = game.get(from);
      if (piece == null) return false;
      if (piece.color != game.turn) return false;
      
      // Create a copy to test the move
      final testGame = chess_lib.Chess();
      testGame.load(game.fen);
      
      final originalFen = testGame.fen;
      final originalTurn = testGame.turn;
      
      // Try to make the move - the chess library validates legality
      final moveResult = testGame.move({'from': from, 'to': to});
      if (moveResult == null) {
        return false; // Move was rejected by chess library (invalid move)
      }
      
      // CRITICAL: Check if FEN actually changed
      final newFen = testGame.fen;
      if (newFen == originalFen) {
        Logger.warning('ChessMoveValidator: Move $from->$to accepted but FEN unchanged!', tag: 'ChessMoveValidator');
        return false; // Move didn't actually change the board
      }
      
      // Verify the turn changed (move was actually executed)
      final newTurn = testGame.turn;
      if (newTurn == originalTurn) {
        Logger.warning('ChessMoveValidator: Move $from->$to did not change turn!', tag: 'ChessMoveValidator');
        return false;
      }
      
      // The chess library's move() method already validates:
      // - Piece movement rules
      // - No moves that leave own king in check
      // - Castling rules
      // - En passant rules
      // So if move() returned non-null and FEN changed, the move is legal
      
      return true;
    } catch (e) {
      Logger.warning('ChessMoveValidator: Exception validating move $from->$to: $e', tag: 'ChessMoveValidator');
      // Move is invalid if it throws an exception
      return false;
    }
  }
  
  /// Execute a move and return the new FEN, or null if invalid
  static String? executeMove(chess_lib.Chess game, String from, String to) {
    try {
      final originalFen = game.fen;
      final moveResult = game.move({'from': from, 'to': to});
      
      if (moveResult == null) {
        Logger.warning('ChessMoveValidator: Move $from->$to was rejected', tag: 'ChessMoveValidator');
        return null;
      }
      
      final newFen = game.fen;
      if (newFen == originalFen) {
        Logger.error('ChessMoveValidator: Move $from->$to accepted but FEN unchanged! Original: $originalFen, New: $newFen', tag: 'ChessMoveValidator');
        return null;
      }
      
      Logger.debug('ChessMoveValidator: Move $from->$to executed. FEN changed from $originalFen to $newFen', tag: 'ChessMoveValidator');
      return newFen;
    } catch (e, stackTrace) {
      Logger.error('Error executing move', error: e, stackTrace: stackTrace, tag: 'ChessMoveValidator');
      return null;
    }
  }
  
  /// Generate all valid moves for the current player
  /// Returns a list of moves in format {'from': 'e2', 'to': 'e4', 'piece': PieceType, ...}
  static List<Map<String, dynamic>> generateAllValidMoves(chess_lib.Chess game) {
    final validMoves = <Map<String, dynamic>>[];
    final files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];
    final currentTurn = game.turn;
    
    // Test every possible move from every square
    for (final file in files) {
      for (final rank in ranks) {
        final fromSquare = '$file$rank';
        final piece = game.get(fromSquare);
        
        // Only check moves from pieces of the current player
        if (piece == null || piece.color != currentTurn) continue;
        
        // Test all possible destinations
        for (final destFile in files) {
          for (final destRank in ranks) {
            final toSquare = '$destFile$destRank';
            if (toSquare == fromSquare) continue;
            
            // Validate the move
            if (_isValidMove(game, fromSquare, toSquare)) {
              // Get the piece at destination for capture info
              final destPiece = game.get(toSquare);
              validMoves.add({
                'from': fromSquare,
                'to': toSquare,
                'piece': piece.type,
                'color': piece.color,
                'captured': destPiece?.type,
                'promotion': null, // TODO: handle promotion
              });
            }
          }
        }
      }
    }
    
    Logger.debug('ChessMoveValidator: Generated ${validMoves.length} valid moves for ${currentTurn}', tag: 'ChessMoveValidator');
    return validMoves;
  }
}

