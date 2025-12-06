import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../../core/services/logger_service.dart';

/// Improved chess board widget with proper rendering and interaction
class ChessBoardWidget extends StatefulWidget {
  final chess_lib.Chess game;
  final Function(String)? onMove; // Called with UCI move (e.g., "e2e4")
  final String? selectedSquare;
  final List<String>? validMoves;
  final bool isWhiteBottom; // Whether white is at bottom
  final bool isInteractive; // Whether board is interactive
  final String? lastMoveFrom; // Highlight last move
  final String? lastMoveTo;
  final bool showValidMoves; // OPTION 2: Enable/disable move highlighting

  const ChessBoardWidget({
    super.key,
    required this.game,
    this.onMove,
    this.selectedSquare,
    this.validMoves,
    this.isWhiteBottom = true,
    this.isInteractive = true,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.showValidMoves = true, // Default: show highlighting
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  String? _selectedSquare;
  List<String> _validMoves = [];
  Function(String)? _onMoveCallback; // Store callback to prevent null issues

  @override
  void initState() {
    super.initState();
    _selectedSquare = widget.selectedSquare;
    _validMoves = widget.validMoves ?? [];
    _onMoveCallback = widget.onMove;
  }

  @override
  void didUpdateWidget(ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update callback reference
    _onMoveCallback = widget.onMove;
    
    if (oldWidget.game.fen != widget.game.fen) {
      Logger.debug('didUpdateWidget: FEN changed, clearing selection', tag: 'ChessBoardWidget');
      setState(() {
        _selectedSquare = null;
        _validMoves = [];
      });
    }
    // Only update from widget props if they're explicitly provided
    if (widget.selectedSquare != null || widget.validMoves != null) {
      _selectedSquare = widget.selectedSquare;
      _validMoves = widget.validMoves ?? [];
    }
  }

  void _onSquareTap(String square) {
    Logger.debug('_onSquareTap: Tapped $square, isInteractive=${widget.isInteractive}, onMove=${widget.onMove != null}, currentTurn=${widget.game.turn}', tag: 'ChessBoardWidget');
    
    if (!widget.isInteractive) {
      Logger.warning('_onSquareTap: Board is not interactive', tag: 'ChessBoardWidget');
      return;
    }

    if (_selectedSquare == null) {
      // Select a piece
      final piece = widget.game.get(square);
      Logger.debug('_onSquareTap: Selecting piece at $square, piece=${piece?.type}, color=${piece?.color}, turn=${widget.game.turn}', tag: 'ChessBoardWidget');
      
      if (piece != null && piece.color == widget.game.turn) {
        final validMoves = _getValidMovesForSquare(square);
        Logger.debug('_onSquareTap: Selected $square, found ${validMoves.length} valid moves: $validMoves', tag: 'ChessBoardWidget');
        setState(() {
          _selectedSquare = square;
          _validMoves = validMoves;
        });
      } else {
        Logger.debug('_onSquareTap: Cannot select - piece is null or wrong color', tag: 'ChessBoardWidget');
      }
    } else {
      // Try to make a move
      Logger.debug('_onSquareTap: Selected square is $_selectedSquare, tapped $square, validMoves=$_validMoves', tag: 'ChessBoardWidget');
      
      if (_validMoves.contains(square)) {
        final moveUCI = '$_selectedSquare$square';
        Logger.debug('_onSquareTap: Valid move detected, calling _makeMove with $moveUCI', tag: 'ChessBoardWidget');
        _makeMove(moveUCI);
      } else {
        // Select a different piece or deselect
        final piece = widget.game.get(square);
        if (piece != null && piece.color == widget.game.turn) {
          Logger.debug('_onSquareTap: Selecting different piece at $square', tag: 'ChessBoardWidget');
          setState(() {
            _selectedSquare = square;
            _validMoves = _getValidMovesForSquare(square);
          });
        } else {
          Logger.debug('_onSquareTap: Deselecting piece', tag: 'ChessBoardWidget');
          setState(() {
            _selectedSquare = null;
            _validMoves = [];
          });
        }
      }
    }
  }

  void _makeMove(String moveUCI) {
    try {
      Logger.debug('_makeMove: Attempting move $moveUCI, onMove=${widget.onMove != null}, isInteractive=${widget.isInteractive}', tag: 'ChessBoardWidget');
      
      // Check if promotion is needed
      if (moveUCI.length < 4) {
        Logger.error('_makeMove: Invalid moveUCI format: $moveUCI', tag: 'ChessBoardWidget');
        return;
      }
      
      final fromSquare = moveUCI.substring(0, 2);
      final toSquare = moveUCI.substring(2, 4);
      final piece = widget.game.get(fromSquare);
      
      if (piece == null) {
        Logger.warning('_makeMove: No piece at $fromSquare', tag: 'ChessBoardWidget');
        setState(() {
          _selectedSquare = null;
          _validMoves = [];
        });
        return;
      }
      
      if (piece.type == chess_lib.PieceType.PAWN) {
        final toRank = int.parse(toSquare[1]);
        if ((piece.color == chess_lib.Color.WHITE && toRank == 8) ||
            (piece.color == chess_lib.Color.BLACK && toRank == 1)) {
          // Need promotion - show dialog
          Logger.debug('_makeMove: Pawn promotion needed for $moveUCI', tag: 'ChessBoardWidget');
          _showPromotionDialog(fromSquare, toSquare);
          return;
        }
      }

      // Use stored callback to prevent null issues during rebuilds
      final callback = _onMoveCallback ?? widget.onMove;
      
      if (callback != null) {
        Logger.debug('_makeMove: Calling onMove callback with $moveUCI', tag: 'ChessBoardWidget');
        // Call the move callback first
        try {
          callback(moveUCI);
          // Clear selection after calling callback (move should succeed)
          setState(() {
            _selectedSquare = null;
            _validMoves = [];
          });
        } catch (e, stackTrace) {
          Logger.error('_makeMove: Error calling onMove callback', error: e, stackTrace: stackTrace, tag: 'ChessBoardWidget');
          // On error, keep selection so user can try again
        }
      } else {
        Logger.warning('_makeMove: onMove callback is null - cannot make move. isInteractive=${widget.isInteractive}, game.turn=${widget.game.turn}', tag: 'ChessBoardWidget');
        // Don't clear selection if callback is null - user should see the piece is still selected
        // Show a visual indicator that the move failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make move - game state may have changed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Logger.error('_makeMove: Error making move', error: e, stackTrace: stackTrace, tag: 'ChessBoardWidget');
      // On error, clear selection
      setState(() {
        _selectedSquare = null;
        _validMoves = [];
      });
    }
  }

  void _showPromotionDialog(String from, String to) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote Pawn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPromotionButton('Queen', 'q', from, to),
            _buildPromotionButton('Rook', 'r', from, to),
            _buildPromotionButton('Bishop', 'b', from, to),
            _buildPromotionButton('Knight', 'n', from, to),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionButton(String name, String piece, String from, String to) {
    return ListTile(
      title: Text(name),
      leading: Text(_getPieceSymbolForPromotion(piece)),
      onTap: () {
        Navigator.pop(context);
        final moveUCI = '$from$to$piece';
        if (widget.onMove != null) {
          widget.onMove!(moveUCI);
        }
        setState(() {
          _selectedSquare = null;
          _validMoves = [];
        });
      },
    );
  }

  String _getPieceSymbolForPromotion(String piece) {
    final isWhite = widget.game.turn == chess_lib.Color.WHITE;
    switch (piece.toLowerCase()) {
      case 'q':
        return isWhite ? '♕' : '♛';
      case 'r':
        return isWhite ? '♖' : '♜';
      case 'b':
        return isWhite ? '♗' : '♝';
      case 'n':
        return isWhite ? '♘' : '♞';
      default:
        return '';
    }
  }

  List<String> _getValidMovesForSquare(String square) {
    // OPTION 2: If highlighting is disabled, return empty list
    if (!widget.showValidMoves) return [];
    
    try {
      final piece = widget.game.get(square);
      if (piece == null) return [];
      
      // Check if it's the piece's turn
      if (piece.color != widget.game.turn) return [];
      
      // OPTION 1: Use generate_moves() - most efficient
      // Move objects have .from and .to as 0x88 indices
      try {
        final allMoves = widget.game.generate_moves();
        final validMoves = <String>[];
        final fromIndex = _squareToIndex(square);
        
        for (final move in allMoves) {
          if (move.from == fromIndex) {
            final toSquare = _indexToSquare(move.to);
            validMoves.add(toSquare);
          }
        }
        
        if (validMoves.isNotEmpty) {
          return validMoves;
        }
      } catch (e) {
        Logger.debug('generate_moves() failed, falling back to smart filtering: $e', tag: 'ChessBoardWidget');
      }
      
      // OPTION 3: Smart piece-based filtering (fallback)
      return _getValidMovesSmartFiltering(square, piece);
    } catch (e) {
      Logger.error('Error getting valid moves for $square', error: e, tag: 'ChessBoardWidget');
      return [];
    }
  }
  
  /// OPTION 3: Smart piece-based move filtering
  /// Only tests squares that could be valid based on piece type
  /// Much faster than testing all 64 squares
  List<String> _getValidMovesSmartFiltering(String square, chess_lib.Piece piece) {
    final validMoves = <String>[];
    final testGame = chess_lib.Chess();
    testGame.load(widget.game.fen);
    
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    
    // Get candidate squares based on piece type
    final candidateSquares = <String>[];
    
    switch (piece.type) {
      case chess_lib.PieceType.PAWN:
        // Pawns move forward (1 or 2 squares from starting position)
        // Can capture diagonally
        final direction = piece.color == chess_lib.Color.WHITE ? 1 : -1;
        final newRank = rank + direction;
        if (newRank >= 0 && newRank < 8) {
          // Forward move
          candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + file)}${newRank + 1}');
          // Double move from starting position
          if ((piece.color == chess_lib.Color.WHITE && rank == 1) ||
              (piece.color == chess_lib.Color.BLACK && rank == 6)) {
            candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + file)}${newRank + 1 + direction}');
          }
        }
        // Diagonal captures
        for (final fileOffset in [-1, 1]) {
          final captureFile = file + fileOffset;
          if (captureFile >= 0 && captureFile < 8 && newRank >= 0 && newRank < 8) {
            candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + captureFile)}${newRank + 1}');
          }
        }
        break;
        
      case chess_lib.PieceType.KNIGHT:
        // Knights move in L-shapes
        for (final rankOffset in [-2, -1, 1, 2]) {
          for (final fileOffset in [-2, -1, 1, 2]) {
            if (rankOffset.abs() == fileOffset.abs()) continue; // Must be L-shape
            final newFile = file + fileOffset;
            final newRank = rank + rankOffset;
            if (newFile >= 0 && newFile < 8 && newRank >= 0 && newRank < 8) {
              candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + newFile)}${newRank + 1}');
            }
          }
        }
        break;
        
      case chess_lib.PieceType.KING:
        // King moves one square in any direction
        for (final rankOffset in [-1, 0, 1]) {
          for (final fileOffset in [-1, 0, 1]) {
            if (rankOffset == 0 && fileOffset == 0) continue;
            final newFile = file + fileOffset;
            final newRank = rank + rankOffset;
            if (newFile >= 0 && newFile < 8 && newRank >= 0 && newRank < 8) {
              candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + newFile)}${newRank + 1}');
            }
          }
        }
        break;
        
      case chess_lib.PieceType.ROOK:
      case chess_lib.PieceType.BISHOP:
      case chess_lib.PieceType.QUEEN:
        // Rooks, Bishops, and Queens move in lines
        final directions = piece.type == chess_lib.PieceType.ROOK
            ? [
                [0, 1], [0, -1], [1, 0], [-1, 0] // Horizontal and vertical
              ]
            : piece.type == chess_lib.PieceType.BISHOP
                ? [
                    [1, 1], [1, -1], [-1, 1], [-1, -1] // Diagonals
                  ]
                : [
                    [0, 1], [0, -1], [1, 0], [-1, 0], // Rook moves
                    [1, 1], [1, -1], [-1, 1], [-1, -1] // Bishop moves
                  ];
        
        for (final dir in directions) {
          for (int i = 1; i < 8; i++) {
            final newFile = file + dir[0] * i;
            final newRank = rank + dir[1] * i;
            if (newFile >= 0 && newFile < 8 && newRank >= 0 && newRank < 8) {
              candidateSquares.add('${String.fromCharCode('a'.codeUnitAt(0) + newFile)}${newRank + 1}');
            } else {
              break; // Out of bounds
            }
          }
        }
        break;
    }
    
    // Test each candidate square
    for (final toSquare in candidateSquares) {
      if (toSquare == square) continue;
      
      final originalFen = testGame.fen;
      final moveResult = testGame.move({'from': square, 'to': toSquare});
      
      if (moveResult != null) {
        final newFen = testGame.fen;
        if (newFen != originalFen) {
          validMoves.add(toSquare);
        }
        testGame.load(widget.game.fen); // Reset
      }
    }
    
    return validMoves;
  }
  
  /// Convert square name (e.g., "e2") to 0x88 index
  /// 0x88 format: rank in upper 4 bits, file in lower 4 bits
  /// Example: e2 = file 4 (e), rank 1 (2-1) = 0x11 = 17
  int _squareToIndex(String square) {
    if (square.length != 2) {
      Logger.error('_squareToIndex: Invalid square format: $square', tag: 'ChessBoardWidget');
      return 0;
    }
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final index = (rank << 4) | file; // 0x88 format
    Logger.debug('_squareToIndex: $square -> file=$file, rank=$rank, index=$index (0x${index.toRadixString(16)})', tag: 'ChessBoardWidget');
    return index;
  }

  /// Convert chess library index to square name
  /// Uses EXACT same implementation as chess_service.dart and chess_ai_service.dart (proven to work)
  String _indexToSquare(int index) {
    final file = index & 0x0F; // Lower 4 bits
    final rank = index >> 4; // Upper 4 bits
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    return '$fileChar${rank + 1}';
  }

  String _getPieceSymbol(chess_lib.Piece? piece) {
    if (piece == null) return '';
    
    final symbols = {
      chess_lib.PieceType.PAWN: piece.color == chess_lib.Color.WHITE ? '♙' : '♟',
      chess_lib.PieceType.ROOK: piece.color == chess_lib.Color.WHITE ? '♖' : '♜',
      chess_lib.PieceType.KNIGHT: piece.color == chess_lib.Color.WHITE ? '♘' : '♞',
      chess_lib.PieceType.BISHOP: piece.color == chess_lib.Color.WHITE ? '♗' : '♝',
      chess_lib.PieceType.QUEEN: piece.color == chess_lib.Color.WHITE ? '♕' : '♛',
      chess_lib.PieceType.KING: piece.color == chess_lib.Color.WHITE ? '♔' : '♚',
    };
    
    return symbols[piece.type] ?? '';
  }

  Color _getSquareColor(int row, int col, bool isLight) {
    // Highlight last move
    final square = _getSquareName(row, col);
    if (square == widget.lastMoveFrom || square == widget.lastMoveTo) {
      return Colors.yellow.shade300;
    }

    // Highlight selected square
    if (_selectedSquare == square) {
      return Colors.blue.shade300;
    }

    // Highlight valid moves (OPTION 2: only if enabled)
    if (widget.showValidMoves && _validMoves.contains(square)) {
      return Colors.green.shade200;
    }

    // Default colors
    return isLight ? Colors.brown.shade200 : Colors.brown.shade600;
  }

  String _getSquareName(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    // When white is at bottom: row 0 = rank 8, row 7 = rank 1
    // When black is at bottom: row 0 = rank 1, row 7 = rank 8
    final rank = widget.isWhiteBottom ? (8 - row) : (row + 1);
    return '$file$rank';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown.shade800, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // File labels (a-h)
          if (!widget.isWhiteBottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(8, (i) {
                final file = String.fromCharCode('a'.codeUnitAt(0) + i);
                return SizedBox(
                  width: MediaQuery.of(context).size.width / 10,
                  child: Center(
                    child: Text(
                      file,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ),
          // Board
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
            ),
            itemCount: 64,
            itemBuilder: (context, index) {
              final row = index ~/ 8;
              final col = index % 8;
              final isLight = (row + col) % 2 == 0;
              
              // Calculate square name directly from grid position
              // Grid index 0-63 maps to squares a1-h8 when white is at bottom
              // When white is at bottom: row 0 = rank 8, row 7 = rank 1
              // When black is at bottom: row 0 = rank 1, row 7 = rank 8
              final square = _getSquareName(row, col);
              
              final piece = widget.game.get(square);
              final isSelected = _selectedSquare == square;
              final isValidMove = _validMoves.contains(square);

              return GestureDetector(
                onTap: widget.isInteractive ? () => _onSquareTap(square) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getSquareColor(row, col, isLight),
                    border: isSelected
                        ? Border.all(color: Colors.blue, width: 3)
                        : isValidMove
                            ? Border.all(color: Colors.green, width: 2)
                            : null,
                  ),
                  child: Stack(
                    children: [
                      // Rank labels (1-8)
                      if (col == 0)
                        Positioned(
                          left: 2,
                          top: 2,
                          child: Text(
                            widget.isWhiteBottom
                                ? (8 - row).toString()
                                : (row + 1).toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      // File labels (a-h)
                      if (row == 7)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Text(
                            String.fromCharCode('a'.codeUnitAt(0) + col),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      // Piece
                      Center(
                        child: Text(
                          _getPieceSymbol(piece),
                          style: TextStyle(
                            fontSize: 32,
                            color: piece?.color == chess_lib.Color.WHITE
                                ? Colors.white
                                : Colors.black,
                            shadows: [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // File labels (a-h)
          if (widget.isWhiteBottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(8, (i) {
                final file = String.fromCharCode('a'.codeUnitAt(0) + i);
                return SizedBox(
                  width: MediaQuery.of(context).size.width / 10,
                  child: Center(
                    child: Text(
                      file,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

