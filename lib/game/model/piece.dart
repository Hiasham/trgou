import 'package:trgou/game/model/player.dart';

class Piece {
  final int pieceId;
  final Player player;
  final int pathIndex;

  const Piece({
    required this.pieceId,
    required this.player,
    required this.pathIndex,
  });

  Piece copyWith({
    int? pieceId,
    Player? player,
    int? pathIndex,
  }) {
    return Piece(
      pieceId: pieceId ?? this.pieceId,
      player: player ?? this.player,
      pathIndex: pathIndex ?? this.pathIndex,
    );
  }
}