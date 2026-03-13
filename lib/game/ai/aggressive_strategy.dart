import 'package:trgou/game/rules/valid_moves.dart';
import 'package:trgou/game/controller/game_state.dart';

int? aggressiveStrategy(GameState state) {
  final moves = getValidMoves(state);
  if (moves.isEmpty) return null;

  ValidMove best = moves.first;
  for (final m in moves) {
    if (m.newPathIndex > best.newPathIndex) {
      best = m;
    } else if (m.newPathIndex == best.newPathIndex && m.fromPathIndex > best.fromPathIndex) {
      best = m;
    }
  }
  return best.fromTileId;
}
