import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExplanationLogEntry {
  final String id;
  final String timestampIso;
  final String eventType;
  final int matchSeed;
  final int randomCallCount;
  final String gameMode;
  final String currentPlayer;
  final String? winner;
  final String? aiStyleOverride;
  final int? pieceId;
  final int? fromTileId;
  final int? toTileId;
  final int? fromPathIndex;
  final int? toPathIndex;
  final int? captureCount;
  final bool? landedOnRosette;
  final bool? reachedFinish;
  final double? progressScore;
  final double? safetyScore;
  final double? aggressionScore;
  final double? totalScore;
  final double? weightProgress;
  final double? weightSafety;
  final double? weightAggression;
  final double? inferredPlayerProgress;
  final double? inferredPlayerSafety;
  final double? inferredPlayerAggression;
  final double? inferredPlayerConfidence;
  final double? responseEfficacy;
  final List<MoveScoreTrace> candidateMoveScores;
  final String playerFacingExplanation;
  final String? debugDetails;

  const ExplanationLogEntry({
    required this.id,
    required this.timestampIso,
    required this.eventType,
    required this.matchSeed,
    required this.randomCallCount,
    required this.gameMode,
    required this.currentPlayer,
    required this.winner,
    required this.aiStyleOverride,
    required this.pieceId,
    required this.fromTileId,
    required this.toTileId,
    required this.fromPathIndex,
    required this.toPathIndex,
    required this.captureCount,
    required this.landedOnRosette,
    required this.reachedFinish,
    required this.progressScore,
    required this.safetyScore,
    required this.aggressionScore,
    required this.totalScore,
    required this.weightProgress,
    required this.weightSafety,
    required this.weightAggression,
    required this.inferredPlayerProgress,
    required this.inferredPlayerSafety,
    required this.inferredPlayerAggression,
    required this.inferredPlayerConfidence,
    required this.responseEfficacy,
    required this.candidateMoveScores,
    required this.playerFacingExplanation,
    required this.debugDetails,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timestampIso': timestampIso,
      'eventType': eventType,
      'matchSeed': matchSeed,
      'randomCallCount': randomCallCount,
      'gameMode': gameMode,
      'currentPlayer': currentPlayer,
      'winner': winner,
      'aiStyleOverride': aiStyleOverride,
      'pieceId': pieceId,
      'fromTileId': fromTileId,
      'toTileId': toTileId,
      'fromPathIndex': fromPathIndex,
      'toPathIndex': toPathIndex,
      'captureCount': captureCount,
      'landedOnRosette': landedOnRosette,
      'reachedFinish': reachedFinish,
      'progressScore': progressScore,
      'safetyScore': safetyScore,
      'aggressionScore': aggressionScore,
      'totalScore': totalScore,
      'weightProgress': weightProgress,
      'weightSafety': weightSafety,
      'weightAggression': weightAggression,
      'inferredPlayerProgress': inferredPlayerProgress,
      'inferredPlayerSafety': inferredPlayerSafety,
      'inferredPlayerAggression': inferredPlayerAggression,
      'inferredPlayerConfidence': inferredPlayerConfidence,
      'responseEfficacy': responseEfficacy,
      'candidateMoveScores': candidateMoveScores
          .map((MoveScoreTrace trace) => trace.toJson())
          .toList(),
      'playerFacingExplanation': playerFacingExplanation,
      'debugDetails': debugDetails,
    };
  }
}

class MoveScoreTrace {
  final int pieceId;
  final int fromTileId;
  final int toTileId;
  final double progressScore;
  final double safetyScore;
  final double aggressionScore;
  final double totalScore;
  final bool selected;

  const MoveScoreTrace({
    required this.pieceId,
    required this.fromTileId,
    required this.toTileId,
    required this.progressScore,
    required this.safetyScore,
    required this.aggressionScore,
    required this.totalScore,
    required this.selected,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pieceId': pieceId,
      'fromTileId': fromTileId,
      'toTileId': toTileId,
      'progressScore': progressScore,
      'safetyScore': safetyScore,
      'aggressionScore': aggressionScore,
      'totalScore': totalScore,
      'selected': selected,
    };
  }
}

class ExplanationEventLogger {
  static const String _storageKey = 'trgou.explanation_logs.v1';
  static const int _maxEntries = 500;

  const ExplanationEventLogger();

  Future<void> append(ExplanationLogEntry entry) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);

    final List<dynamic> existing = raw == null || raw.isEmpty
        ? <dynamic>[]
        : (jsonDecode(raw) as List<dynamic>);
    existing.add(entry.toJson());

    if (existing.length > _maxEntries) {
      existing.removeRange(0, existing.length - _maxEntries);
    }

    await prefs.setString(_storageKey, jsonEncode(existing));
    debugPrint('[ExplanationLog] ${jsonEncode(entry.toJson())}');
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
