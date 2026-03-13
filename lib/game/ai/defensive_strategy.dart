import 'package:trgou/game/rules/valid_moves.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/rules/board_config.dart';

int? defensiveStrategy(GameState state) {
  final moves = getValidMoves(state);
  if (moves.isEmpty) return null;

  final startTileId = BoardConfig.startTileIdFor(state.currentPlayer);

  final fromStart = moves.where((m) => m.fromTileId == startTileId).toList();
  if (fromStart.isNotEmpty) return fromStart.first.fromTileId;

  ValidMove best = moves.first;
  for (final m in moves) {
    if (m.fromPathIndex < best.fromPathIndex) best = m;
  }
  return best.fromTileId;
}
