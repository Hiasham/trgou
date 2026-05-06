import 'package:trgou/game/model/player.dart';

class PathConfig {
  static const List<int> playerOnePath = [
    12, 9, 6, 3, 0, 1, 4, 7, 10, 13, 16, 19, 22, 21, 18, 15
  ];

  static const List<int> playerTwoPath = [
    14, 11, 8, 5, 2, 1, 4, 7, 10, 13, 16, 19, 22, 23, 20, 17
  ];

  List<int> getPath(Player player) {
    switch (player) {
      case Player.playerOne:
        return playerOnePath;
      case Player.playerTwo:
        return playerTwoPath;
    }
  }

  int getTileId(Player player, int pathIndex) {
    return getPath(player)[pathIndex];
  }

  int getPathLength(Player player) {
    return getPath(player).length;
  }
}