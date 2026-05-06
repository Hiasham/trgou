import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trgou/game/controller/game_controller.dart';

import 'package:trgou/game/controller/game_state.dart';

import 'package:trgou/game/persistence/game_state_persistence.dart';



final gameStateProvider = StateNotifierProvider<GameController, GameState>((ref) {

  return GameController();

});




final hasRestorableGameProvider = FutureProvider.autoDispose<bool>((ref) async {

  const GameStatePersistence persistence = GameStatePersistence();

  final PersistedGameSnapshot? snapshot = await persistence.load();

  return snapshot != null;

});

