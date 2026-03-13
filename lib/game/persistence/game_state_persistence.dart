import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/roll.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/rules/board_config.dart';

const String _key = 'trgou_game_state';

Future<void> saveGameState(GameState state) async {
  final prefs = await SharedPreferences.getInstance();
  final map = <String, dynamic>{
    'gameMode': state.gameMode.index,
    'currentPlayer': state.currentPlayer.index,
    'playerOneScore': state.playerOneScore,
    'playerTwoScore': state.playerTwoScore,
    'playerOnePositions': state.playerOnePieces.map((p) => p.position).toList(),
    'playerTwoPositions': state.playerTwoPieces.map((p) => p.position).toList(),
    if (state.lastRoll != null) 'lastRollDice': state.lastRoll!.dice,
  };
  await prefs.setString(_key, jsonEncode(map));
}

Future<GameState?> loadGameState() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_key);
  if (json == null) return null;
  try {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final gameMode = GameMode.values[map['gameMode'] as int];
    final currentPlayer = Player.values[map['currentPlayer'] as int];
    final rawOne = (map['playerOnePositions'] as List<dynamic>?)?.cast<int>() ?? <int>[];
    final rawTwo = (map['playerTwoPositions'] as List<dynamic>?)?.cast<int>() ?? <int>[];
    final playerOnePositions = List<int>.from(rawOne);
    final playerTwoPositions = List<int>.from(rawTwo);
    while (playerOnePositions.length < 7) {
      playerOnePositions.add(-1);
    }
    while (playerTwoPositions.length < 7) {
      playerTwoPositions.add(-1);
    }
    Roll? lastRoll;
    if (map['lastRollDice'] != null) {
      lastRoll = Roll((map['lastRollDice'] as List<dynamic>).cast<bool>());
    }
    final playerOnePieces = playerOnePositions
        .take(7)
        .map((pos) => Piece(owner: Player.one, position: pos))
        .toList();
    final playerTwoPieces = playerTwoPositions
        .take(7)
        .map((pos) => Piece(owner: Player.two, position: pos))
        .toList();
    return GameState(
      tiles: List<Tile>.from(BoardConfig.tiles),
      gameMode: gameMode,
      currentPlayer: currentPlayer,
      lastRoll: lastRoll,
      playerOnePieces: playerOnePieces,
      playerTwoPieces: playerTwoPieces,
      playerOneScore: map['playerOneScore'] as int? ?? 0,
      playerTwoScore: map['playerTwoScore'] as int? ?? 0,
    );
  } catch (_) {
    return null;
  }
}

Future<bool> hasSavedGame() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_key);
}
