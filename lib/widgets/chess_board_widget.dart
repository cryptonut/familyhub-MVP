import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

/// A simple chess board widget that displays the board and handles piece selection
class ChessBoardWidget extends StatefulWidget {
  final chess_lib.Chess game;
  final Function(String)? onMove;
  final String? selectedSquare;
  final List<String>? validMoves;

  const ChessBoardWidget({
    super.key,
    required this.game,
    this.onMove,
    this.selectedSquare,
    this.validMoves,
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
    // Reset selection when game changes
    if (oldWidget.game.fen != widget.game.fen) {
      setState(() {
        _selectedSquare = null;
        _validMoves = [];
      });
    }
  }

  void _onSquareTap(String square) {
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
      final move = '$_selectedSquare$square';
      if (_validMoves.contains(square) || _validMoves.contains(move)) {
        if (widget.onMove != null) {
          widget.onMove!(move);
        }
        setState(() {
          _selectedSquare = null;
          _validMoves = [];
        });
      } else {
        // Select a different piece
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

  /// Convert square index to square name (e.g., "e2")
  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = (index ~/ 8) + 1;
    return '$file$rank';
  }

  List<String> _getValidMovesForSquare(String square) {
    final moves = widget.game.generate_moves({'square': square, 'verbose': true});
    return moves.map((m) => _indexToSquare(m.to)).toList();
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

  Color _getSquareColor(int row, int col) {
    final isLight = (row + col) % 2 == 0;
    if (_selectedSquare == _getSquareName(row, col)) {
      return Colors.blue.shade300;
    }
    if (_validMoves.contains(_getSquareName(row, col))) {
      return Colors.green.shade200;
    }
    return isLight ? Colors.brown.shade200 : Colors.brown.shade600;
  }

  String _getSquareName(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = (8 - row).toString();
    return '$file$rank';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown.shade800, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final square = _getSquareName(row, col);
          final piece = widget.game.get(square);
          final isSelected = _selectedSquare == square;
          final isValidMove = _validMoves.contains(square);

          return GestureDetector(
            onTap: () => _onSquareTap(square),
            child: Container(
              decoration: BoxDecoration(
                color: _getSquareColor(row, col),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 3)
                    : isValidMove
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
              ),
              child: Center(
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
            ),
          );
        },
      ),
    );
  }
}

