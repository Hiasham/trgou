import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/ai/ai_explanation.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';

class PersistedGameSnapshot {
  final GameState state;
  final AIStyleOverride? aiStyleOverride;

  const PersistedGameSnapshot({
    required this.state,
    required this.aiStyleOverride,
  });
}

class GameStatePersistence {
  static const String _storageKey = 'trgou.latest_game_state.v1';

  const GameStatePersistence();

  Future<void> save({
    required GameState state,
    required AIStyleOverride? aiStyleOverride,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String payload = jsonEncode(<String, dynamic>{
      'gameMode': state.gameMode.name,
      'currentPlayer': state.currentPlayer.name,
      'selectedTileId': state.selectedTileId,
      'diceRoll': state.diceRoll,
      'rollShakeCounter': state.rollShakeCounter,
      'winner': state.winner?.name,
      'aiStyleOverride': aiStyleOverride?.name,
      'matchSeed': state.matchSeed,
      'randomCallCount': state.randomCallCount,
      'isDeterminingFirstPlayer': state.isDeterminingFirstPlayer,
      'openingRollPlayerOne': state.openingRollPlayerOne,
      'openingRollPlayerTwo': state.openingRollPlayerTwo,
      'pieces': state.pieces
          .map(
            (Piece piece) => <String, dynamic>{
              'pieceId': piece.pieceId,
              'player': piece.player.name,
              'pathIndex': piece.pathIndex,
            },
          )
          .toList(),
      'latestAiExplanation': state.latestAiExplanation == null
          ? null
          : <String, dynamic>{
              'pieceId': state.latestAiExplanation!.pieceId,
              'fromTileId': state.latestAiExplanation!.fromTileId,
              'toTileId': state.latestAiExplanation!.toTileId,
              'progressScore': state.latestAiExplanation!.progressScore,
              'safetyScore': state.latestAiExplanation!.safetyScore,
              'aggressionScore': state.latestAiExplanation!.aggressionScore,
              'totalScore': state.latestAiExplanation!.totalScore,
              'explanation': state.latestAiExplanation!.explanation,
              'debugDetails': state.latestAiExplanation!.debugDetails,
            },
    });

    await prefs.setString(_storageKey, payload);
  }

  Future<PersistedGameSnapshot?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? payload = prefs.getString(_storageKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> json =
          jsonDecode(payload) as Map<String, dynamic>;
      final GameMode gameMode = _parseGameMode(json['gameMode'] as String?);
      final int matchSeed =
          (json['matchSeed'] as int?) ?? DateTime.now().microsecondsSinceEpoch;
      final GameState baseState = GameState.initial(
        gameMode: gameMode,
        matchSeed: matchSeed,
      );

      final List<Piece> pieces = _parsePieces(json['pieces']);
      if (pieces.isEmpty) {
        return null;
      }

      final GameState restoredState = GameState(
        board: baseState.board,
        pieces: pieces,
        selectedTileId: json['selectedTileId'] as int?,
        currentPlayer: _parsePlayer(json['currentPlayer'] as String?),
        diceRoll: json['diceRoll'] as int?,
        rollShakeCounter: (json['rollShakeCounter'] as int?) ?? 0,
        winner: _parseNullablePlayer(json['winner'] as String?),
        gameMode: gameMode,
        latestAiExplanation: _parseExplanation(json['latestAiExplanation']),
        matchSeed: matchSeed,
        randomCallCount: (json['randomCallCount'] as int?) ?? 0,
        isDeterminingFirstPlayer:
            (json['isDeterminingFirstPlayer'] as bool?) ?? false,
        openingRollPlayerOne: json['openingRollPlayerOne'] as int?,
        openingRollPlayerTwo: json['openingRollPlayerTwo'] as int?,
      );

      return PersistedGameSnapshot(
        state: restoredState,
        aiStyleOverride: _parseAiStyleOverride(
          json['aiStyleOverride'] as String?,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  List<Piece> _parsePieces(Object? rawPieces) {
    if (rawPieces is! List<dynamic>) {
      return <Piece>[];
    }

    final List<Piece> parsed = <Piece>[];
    for (final dynamic entry in rawPieces) {
      if (entry is! Map) {
        continue;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(entry);

      final int? pieceId = map['pieceId'] as int?;
      final String? playerRaw = map['player'] as String?;
      final int? pathIndex = map['pathIndex'] as int?;
      if (pieceId == null || playerRaw == null || pathIndex == null) {
        continue;
      }

      parsed.add(
        Piece(
          pieceId: pieceId,
          player: _parsePlayer(playerRaw),
          pathIndex: pathIndex,
        ),
      );
    }

    parsed.sort((Piece a, Piece b) => a.pieceId.compareTo(b.pieceId));
    return parsed;
  }

  AIExplanation? _parseExplanation(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);

    final int? pieceId = map['pieceId'] as int?;
    final int? fromTileId = map['fromTileId'] as int?;
    final int? toTileId = map['toTileId'] as int?;
    final double? progressScore = (map['progressScore'] as num?)?.toDouble();
    final double? safetyScore = (map['safetyScore'] as num?)?.toDouble();
    final double? aggressionScore = (map['aggressionScore'] as num?)
        ?.toDouble();
    final double? totalScore = (map['totalScore'] as num?)?.toDouble();
    final String? explanation = map['explanation'] as String?;
    final String? debugDetails = map['debugDetails'] as String?;

    if (pieceId == null ||
        fromTileId == null ||
        toTileId == null ||
        progressScore == null ||
        safetyScore == null ||
        aggressionScore == null ||
        totalScore == null ||
        explanation == null) {
      return null;
    }

    return AIExplanation(
      pieceId: pieceId,
      fromTileId: fromTileId,
      toTileId: toTileId,
      progressScore: progressScore,
      safetyScore: safetyScore,
      aggressionScore: aggressionScore,
      totalScore: totalScore,
      explanation: explanation,
      debugDetails: debugDetails,
    );
  }

  Player _parsePlayer(String? raw) {
    switch (raw) {
      case 'playerTwo':
        return Player.playerTwo;
      case 'playerOne':
      default:
        return Player.playerOne;
    }
  }

  Player? _parseNullablePlayer(String? raw) {
    if (raw == null) {
      return null;
    }
    return _parsePlayer(raw);
  }

  GameMode _parseGameMode(String? raw) {
    switch (raw) {
      case 'aiOpponent':
        return GameMode.aiOpponent;
      case 'hotseat':
      default:
        return GameMode.hotseat;
    }
  }

  AIStyleOverride? _parseAiStyleOverride(String? raw) {
    switch (raw) {
      case 'random':
        return AIStyleOverride.random;
      case 'aggressive':
        return AIStyleOverride.aggressive;
      case 'defensive':
        return AIStyleOverride.defensive;
      case 'progressive':
        return AIStyleOverride.progressive;
      case 'bayesian':
        return AIStyleOverride.bayesian;
      default:
        return null;
    }
  }
}
