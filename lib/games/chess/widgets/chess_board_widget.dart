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
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {
  String? _selectedSquare;
  List<String> _validMoves = [];

  @override
  void initState() {
    super.initState();
    _selectedSquare = widget.selectedSquare;
    _validMoves = widget.validMoves ?? [];
  }

  @override
  void didUpdateWidget(ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.fen != widget.game.fen) {
      setState(() {
        _selectedSquare = null;
        _validMoves = [];
      });
    }
    _selectedSquare = widget.selectedSquare;
    _validMoves = widget.validMoves ?? [];
  }

  void _onSquareTap(String square) {
    if (!widget.isInteractive) return;

    if (_selectedSquare == null) {
      // Select a piece
      final piece = widget.game.get(square);
      if (piece != null && piece.color == widget.game.turn) {
        setState(() {
          _selectedSquare = square;
          _validMoves = _getValidMovesForSquare(square);
        });
      }
    } else {
      // Try to make a move
      if (_validMoves.contains(square)) {
        final moveUCI = '$_selectedSquare$square';
        _makeMove(moveUCI);
      } else {
        // Select a different piece or deselect
        final piece = widget.game.get(square);
        if (piece != null && piece.color == widget.game.turn) {
          setState(() {
            _selectedSquare = square;
            _validMoves = _getValidMovesForSquare(square);
          });
        } else {
          setState(() {
            _selectedSquare = null;
            _validMoves = [];
          });
        }
      }
    }
  }

  void _makeMove(String moveUCI) {
    // Check if promotion is needed
    final fromSquare = moveUCI.substring(0, 2);
    final toSquare = moveUCI.substring(2, 4);
    final piece = widget.game.get(fromSquare);
    
    if (piece?.type == chess_lib.PieceType.PAWN) {
      final toRank = int.parse(toSquare[1]);
      if ((piece!.color == chess_lib.Color.WHITE && toRank == 8) ||
          (piece.color == chess_lib.Color.BLACK && toRank == 1)) {
        // Need promotion - show dialog
        _showPromotionDialog(fromSquare, toSquare);
        return;
      }
    }

    if (widget.onMove != null) {
      widget.onMove!(moveUCI);
    }
    setState(() {
      _selectedSquare = null;
      _validMoves = [];
    });
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
    try {
      final moves = widget.game.generate_moves({'square': square, 'verbose': true});
      return moves.map((m) => _indexToSquare(m.to)).toList();
    } catch (e) {
      Logger.error('Error getting valid moves', error: e, tag: 'ChessBoardWidget');
      return [];
    }
  }

  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = (index ~/ 8) + 1;
    return '$file$rank';
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

    // Highlight valid moves
    if (_validMoves.contains(square)) {
      return Colors.green.shade200;
    }

    // Default colors
    return isLight ? Colors.brown.shade200 : Colors.brown.shade600;
  }

  String _getSquareName(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = widget.isWhiteBottom ? (8 - row).toString() : (row + 1).toString();
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
              
              // Adjust for board orientation
              final displayRow = widget.isWhiteBottom ? 7 - row : row;
              final displayCol = widget.isWhiteBottom ? col : 7 - col;
              final square = _getSquareName(displayRow, displayCol);
              
              final piece = widget.game.get(square);
              final isSelected = _selectedSquare == square;
              final isValidMove = _validMoves.contains(square);

              return GestureDetector(
                onTap: widget.isInteractive ? () => _onSquareTap(square) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getSquareColor(displayRow, displayCol, isLight),
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

