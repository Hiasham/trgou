import 'package:trgou/game/model/board_position.dart';
import 'package:trgou/game/model/tile.dart';

class BoardConfig {
  TrackType getTrackType(int x) {
    switch (x) {
      case 0:
        return TrackType.playerOne;
      case 1:
        return TrackType.shared;
      case 2:
        return TrackType.playerTwo;
      default:
        throw Exception('Invalid x: $x');
    }
  }

  static final Set<BoardPosition> starts = {
    BoardPosition(0, 4),
    BoardPosition(2, 4),
  };

  static final Set<BoardPosition> finishes = {
    BoardPosition(0, 5),
    BoardPosition(2, 5),
  };

  static final Set<BoardPosition> rosettes = {
    BoardPosition(0, 0),
    BoardPosition(2, 0),
    BoardPosition(0, 6),
    BoardPosition(2, 6),
    BoardPosition(1, 3),
  };

  TileType getTileType(int x, int y) {
    final pos = BoardPosition(x, y);

    if (starts.contains(pos)) return TileType.start;
    if (finishes.contains(pos)) return TileType.finish;
    if (rosettes.contains(pos)) return TileType.rosette;

    return TileType.basic;
  }
  
  List<Tile> createBoard() {
    List<Tile> board = [];
    int tileId = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 3; x++) {
        board.add(Tile(tileId: tileId++, boardPosition: BoardPosition(x, y), tileType: getTileType(x, y), trackType: getTrackType(x)));
      }
    }

    return board;
  }
}

