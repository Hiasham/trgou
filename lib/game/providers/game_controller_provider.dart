import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/game/ai/ai_strategy.dart';
import 'package:trgou/game/ai/bot_style.dart';
import 'package:trgou/game/controller/game_controller.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/persistence/game_state_persistence.dart';

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  return GameController();
});

final savedGameStateProvider = FutureProvider<GameState?>((ref) {
  return loadGameState();
});

final botStyleProvider = FutureProvider<BotStyle>((ref) => loadBotStyle());

final botStrategyProvider = FutureProvider<AiStrategy>((ref) async {
  final style = await loadBotStyle();
  return strategyFor(style);
});
