/// Model representing a chess move
class ChessMove {
  final String from; // e.g., "e2"
  final String to; // e.g., "e4"
  final String? promotion; // 'q', 'r', 'b', 'n' for pawn promotion
  final String? san; // Standard Algebraic Notation (e.g., "e4", "Nf3")
  final String uci; // UCI format (e.g., "e2e4")
  final DateTime timestamp;
  final String? comment; // optional move comment
  final int? evaluation; // engine evaluation if available

  ChessMove({
    required this.from,
    required this.to,
    this.promotion,
    this.san,
    required this.uci,
    required this.timestamp,
    this.comment,
    this.evaluation,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'promotion': promotion,
        'san': san,
        'uci': uci,
        'timestamp': timestamp.toIso8601String(),
        'comment': comment,
        'evaluation': evaluation,
      };

  factory ChessMove.fromJson(Map<String, dynamic> json) {
    return ChessMove(
      from: json['from'] as String,
      to: json['to'] as String,
      promotion: json['promotion'] as String?,
      san: json['san'] as String?,
      uci: json['uci'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      comment: json['comment'] as String?,
      evaluation: json['evaluation'] as int?,
    );
  }

  /// Create a move from UCI string (e.g., "e2e4" or "e7e8q")
  factory ChessMove.fromUCI(String uci) {
    if (uci.length < 4 || uci.length > 5) {
      throw ArgumentError('Invalid UCI format: $uci');
    }

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length == 5 ? uci[4] : null;

    return ChessMove(
      from: from,
      to: to,
      promotion: promotion,
      uci: uci,
      timestamp: DateTime.now(),
    );
  }
}

