import 'package:trgou/game/model/board_position.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';

class BoardConfig {
  BoardConfig._();

  static const int player1Column = 0;
  static const int player2Column = 2;

  static const int playerOneStartTileId = 12;
  static const int playerTwoStartTileId = 14;

  static const List<Tile> tiles = [
    Tile(id: 0,  tileType: TileType.rosette, trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 0)),
    Tile(id: 1,  tileType: TileType.basic,   trackType: TrackType.shared   ,  position:  BoardPosition(x: 1, y: 0)),
    Tile(id: 2,  tileType: TileType.rosette, trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 0)),
    Tile(id: 3,  tileType: TileType.basic,   trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 1)),
    Tile(id: 4,  tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 1)),
    Tile(id: 5,  tileType: TileType.basic,   trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 1)),
    Tile(id: 6,  tileType: TileType.basic,   trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 2)),
    Tile(id: 7,  tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 2)),
    Tile(id: 8,  tileType: TileType.basic,   trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 2)),
    Tile(id: 9,  tileType: TileType.basic,   trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 3)),
    Tile(id: 10, tileType: TileType.rosette, trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 3)),
    Tile(id: 11, tileType: TileType.basic,   trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 3)),
    Tile(id: 12, tileType: TileType.start,   trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 4)),
    Tile(id: 13, tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 4)),
    Tile(id: 14, tileType: TileType.start,   trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 4)),
    Tile(id: 15, tileType: TileType.end,     trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 5)),
    Tile(id: 16, tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 5)),
    Tile(id: 17, tileType: TileType.end,     trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 5)),
    Tile(id: 18, tileType: TileType.rosette, trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 6)),
    Tile(id: 19, tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 6)),
    Tile(id: 20, tileType: TileType.rosette, trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 6)),
    Tile(id: 21, tileType: TileType.basic,   trackType: TrackType.playerOne,  position:  BoardPosition(x: 0, y: 7)),
    Tile(id: 22, tileType: TileType.basic,   trackType: TrackType.shared,     position:  BoardPosition(x: 1, y: 7)),
    Tile(id: 23, tileType: TileType.basic,   trackType: TrackType.playerTwo,  position:  BoardPosition(x: 2, y: 7)),
  ];

  static const List<int> playerOnePath = [ 12,  9, 6, 3, 0, 1, 4, 7, 10, 13, 16, 19, 22, 21, 18, 15 ];

  static const List<int> playerTwoPath = [ 14, 11, 8, 5, 2, 1, 4, 7, 10, 13, 16, 19, 22, 23, 20, 17 ];

  static List<int> pathFor(Player player) =>
      player == Player.one ? List.from(playerOnePath) : List.from(playerTwoPath);

  static int pathIndexFor(Player player, int tileId) {
    final path = player == Player.one ? playerOnePath : playerTwoPath;
    final i = path.indexOf(tileId);
    return i;
  }

  static int? tileIdAtPathIndex(Player player, int index) {
    final path = player == Player.one ? playerOnePath : playerTwoPath;
    if (index < 0 || index >= path.length) return null;
    return path[index];
  }

  static int startTileIdFor(Player player) =>
      player == Player.one ? playerOneStartTileId : playerTwoStartTileId;

  static bool isRosetteTile(int tileId) {
    final tile = tiles.firstWhere(
      (t) => t.id == tileId,
      orElse: () => throw StateError('No tile with id $tileId'),
    );
    return tile.tileType == TileType.rosette;
  }
}