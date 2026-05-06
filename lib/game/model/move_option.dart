import 'package:trgou/game/model/tile.dart';

class MoveOption {
  final int pieceId;
  final int fromPathIndex;
  final int toPathIndex;
  final int fromTileId;
  final int toTileId;
  final Tile? destinationTile;

  const MoveOption({
    required this.pieceId,
    required this.fromPathIndex,
    required this.toPathIndex,
    required this.fromTileId,
    required this.toTileId,
    this.destinationTile,
  });
}
