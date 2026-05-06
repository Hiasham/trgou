import 'package:trgou/game/model/board_position.dart';

class Tile {
  final int tileId;
  final BoardPosition boardPosition;
  final TileType tileType;
  final TrackType trackType;

  const Tile({
    required this.tileId,
    required this.boardPosition,
    required this.tileType,
    required this.trackType
  });
}

enum TileType {
  basic,
  rosette,
  start,
  finish
}

enum TrackType {
  playerOne,
  playerTwo,
  shared
}