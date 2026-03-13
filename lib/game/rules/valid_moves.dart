import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/rules/board_config.dart';

class ValidMove {
  const ValidMove({
    required this.fromTileId,
    required this.newTileId,
    required this.fromPathIndex,
    required this.newPathIndex,
  });

  final int fromTileId;
  final int newTileId;
  final int fromPathIndex;
  final int newPathIndex;
}

List<ValidMove> getValidMoves(GameState state) {
  final roll = state.lastRoll;
  if (roll == null) return [];

  final player = state.currentPlayer;
  final pieces = player == Player.one ? state.playerOnePieces : state.playerTwoPieces;
  final path = BoardConfig.pathFor(player);
  final opponentPieces = player == Player.one ? state.playerTwoPieces : state.playerOnePieces;
  final result = <ValidMove>[];

  for (final piece in pieces) {
    final fromTileId = piece.position;
    if (fromTileId < 0) continue;
    final pathIndex = path.indexOf(fromTileId);
    if (pathIndex == -1) continue;
    if (state.tiles.any((t) => t.id == fromTileId && t.isEnd)) continue;

    final newIndex = pathIndex + roll.value;
    if (newIndex >= path.length) continue;

    final newTileId = path[newIndex];
    final destinationIsEnd = state.tiles.any((t) => t.id == newTileId && t.isEnd);
    final destinationIsStart = state.tiles.any((t) => t.id == newTileId && t.tileType == TileType.start);
    final destinationIsRosette = state.tiles.any((t) => t.id == newTileId && t.isRosette);
    final myPieceOnDestination = pieces.any((p) => p.position == newTileId);
    final opponentPieceOnDestination = opponentPieces.any((p) => p.position == newTileId);

    if (newTileId != fromTileId && !destinationIsEnd && !destinationIsStart && myPieceOnDestination) continue;
    if (destinationIsRosette && opponentPieceOnDestination) continue;

    result.add(ValidMove(
      fromTileId: fromTileId,
      newTileId: newTileId,
      fromPathIndex: pathIndex,
      newPathIndex: newIndex,
    ));
  }

  return result;
}
