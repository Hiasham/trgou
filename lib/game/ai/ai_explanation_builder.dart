import 'package:trgou/game/ai/move_evaluation.dart';
import 'package:trgou/game/ai/value_weights.dart';
import 'package:trgou/game/ai/bayesian_learning_model.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/model/tile.dart';

class AdaptiveExplanationBundle {
  final String playerFacing;
  final String debugDetails;

  const AdaptiveExplanationBundle({
    required this.playerFacing,
    required this.debugDetails,
  });
}

class AiExplanationBuilder {
  const AiExplanationBuilder();

  String buildForMove(MoveOption move, {double? totalScore}) {
    final String destinationLabel = _destinationLabel(move);
    return 'Moved piece ${move.pieceId} to $destinationLabel.';
  }

  String buildForEvaluation(MoveEvaluation evaluation) {
    final MoveOption move = evaluation.move;
    final String destinationLabel = _destinationLabel(move);
    return 'Piece ${move.pieceId} to $destinationLabel.';
  }

  String buildSelectionExplanation({
    required MoveEvaluation selected,
    required List<MoveEvaluation> allEvaluations,
    required bool isOpeningPosition,
    required bool areMovesSimilar,
  }) {
    final Tile? destinationTile = selected.move.destinationTile;
    final MoveEvaluation? runnerUp = _findRunnerUp(
      selected: selected,
      allEvaluations: allEvaluations,
    );
    final String confidencePrefix = _confidencePrefix(
      selected: selected,
      runnerUp: runnerUp,
    );
    final String valueBlend = _describeValueBlend(selected);

    if (isOpeningPosition) {
      if (_isSafety(selected)) {
        return '$confidencePrefix I opened cautiously because the early position was vulnerable.';
      }
      return '$confidencePrefix I opened with progress because the immediate gain outweighed the early risk.';
    }

    if (areMovesSimilar) {
      if (_isSafety(selected)) {
        return '$confidencePrefix The options were close, so I preferred the safer line with lower capture exposure.';
      }
      return '$confidencePrefix The options were close, so I chose the line with slightly stronger forward progress.';
    }

    if (destinationTile != null && destinationTile.tileType == TileType.rosette) {
      if (_isSafety(selected)) {
        return '$confidencePrefix I chose the rosette because it improves safety while preserving progress.';
      }
      return '$confidencePrefix I chose the rosette to secure the position and reduce immediate counterplay.';
    }

    if (destinationTile != null && destinationTile.tileType == TileType.finish) {
      return '$confidencePrefix I prioritised bringing a piece home because finishing is the highest-value progress outcome.';
    }

    if (_isAggressive(selected)) {
      return '$confidencePrefix I chose this move to pressure the opponent and disrupt their progress, while still keeping $valueBlend.';
    }
    if (_isRiskyProgress(selected)) {
      return '$confidencePrefix I accepted a calculated risk because the progress gain was stronger than the added exposure.';
    }
    if (_isSafety(selected)) {
      return '$confidencePrefix I shifted toward safety here to reduce capture risk and keep control of the turn.';
    }
    return '$confidencePrefix I selected this move because it offered the best overall balance of progress, safety, and pressure.';
  }

  AdaptiveExplanationBundle buildAdaptiveBeliefExplanation({
    required MoveEvaluation observed,
    required int captureCount,
    required bool landedOnRosette,
    required bool reachedFinish,
    required PlayerTendencies beforeBeliefs,
    required PlayerTendencies afterBeliefs,
    required ValueWeights beforeResponse,
    required ValueWeights afterResponse,
  }) {
    final String playerStyle = _classifyPlayerStyle(
      observed: observed,
      captureCount: captureCount,
      landedOnRosette: landedOnRosette,
      reachedFinish: reachedFinish,
    );
    final String aiResponse = _classifyAiResponse(
      beforeResponse: beforeResponse,
      afterResponse: afterResponse,
    );
    final String valueShift = _describeResponseValueShift(
      beforeResponse: beforeResponse,
      afterResponse: afterResponse,
    );

    final String playerFacing = 'That move showed $playerStyle tendencies, '
        'so I\'m $aiResponse. $valueShift';

    final String debugDetails = _buildDebugDetails(
      beforeBeliefs: beforeBeliefs,
      afterBeliefs: afterBeliefs,
      beforeResponse: beforeResponse,
      afterResponse: afterResponse,
    );

    return AdaptiveExplanationBundle(
      playerFacing: playerFacing,
      debugDetails: debugDetails,
    );
  }

  bool _isAggressive(MoveEvaluation evaluation) {
    return evaluation.aggressionScore > 0.6;
  }

  bool _isSafety(MoveEvaluation evaluation) {
    return evaluation.safetyScore > evaluation.aggressionScore;
  }

  bool _isRiskyProgress(MoveEvaluation evaluation) {
    return evaluation.progressScore > evaluation.safetyScore &&
        evaluation.safetyScore < -0.15;
  }

  MoveEvaluation? _findRunnerUp({
    required MoveEvaluation selected,
    required List<MoveEvaluation> allEvaluations,
  }) {
    final List<MoveEvaluation> alternatives = allEvaluations
        .where(
          (evaluation) =>
              evaluation.move.pieceId != selected.move.pieceId ||
              evaluation.move.fromTileId != selected.move.fromTileId ||
              evaluation.move.toTileId != selected.move.toTileId,
        )
        .toList();
    if (alternatives.isEmpty) {
      return null;
    }
    alternatives.sort(
      (a, b) => b.totalScore.compareTo(a.totalScore),
    );
    return alternatives.first;
  }

  String _confidencePrefix({
    required MoveEvaluation selected,
    required MoveEvaluation? runnerUp,
  }) {
    if (runnerUp == null) {
      return 'This was the only legal move.';
    }
    final double gap = selected.totalScore - runnerUp.totalScore;
    if (gap >= 0.35) {
      return 'This was a clear best option.';
    }
    if (gap >= 0.15) {
      return 'This was the strongest available option.';
    }
    return 'This was a marginally better option.';
  }

  String _describeValueBlend(MoveEvaluation evaluation) {
    final Map<String, double> values = <String, double>{
      'progress': evaluation.progressScore,
      'safety': evaluation.safetyScore,
      'aggression': evaluation.aggressionScore,
    };
    final List<MapEntry<String, double>> sorted = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted[0].key} and ${sorted[1].key} in balance';
  }

  String _destinationLabel(MoveOption move) {
    final Tile? tile = move.destinationTile;
    if (tile == null) {
      return 'tile ${move.toTileId}';
    }

    return switch (tile.tileType) {
      TileType.rosette => 'rosette',
      TileType.finish => 'finish',
      TileType.start => 'start',
      TileType.basic => 'tile ${move.toTileId}',
    };
  }

  String _classifyPlayerStyle({
    required MoveEvaluation observed,
    required int captureCount,
    required bool landedOnRosette,
    required bool reachedFinish,
  }) {
    if (captureCount > 0 || observed.aggressionScore > 0.7) {
      return 'aggressive';
    }
    if (reachedFinish || observed.progressScore > 0.7) {
      return 'progress-focused';
    }
    if (landedOnRosette || observed.safetyScore >= observed.progressScore) {
      return 'defensive';
    }
    return 'a balance of progress and safety';
  }

  String _classifyAiResponse({
    required ValueWeights beforeResponse,
    required ValueWeights afterResponse,
  }) {
    final double aggressionDelta =
        afterResponse.aggression - beforeResponse.aggression;
    final double safetyDelta = afterResponse.safety - beforeResponse.safety;
    final double progressDelta = afterResponse.progress - beforeResponse.progress;

    if (safetyDelta >= 0.05 && aggressionDelta <= -0.02) {
      return 'adjusting towards a safer strategy to reduce capture risk';
    }
    if (aggressionDelta >= 0.05) {
      return 'responding with more pressure';
    }
    if (progressDelta >= 0.05) {
      return 'increasing direct progress pressure';
    }
    return 'making a measured counter-adjustment';
  }

  String _describeResponseValueShift({
    required ValueWeights beforeResponse,
    required ValueWeights afterResponse,
  }) {
    final double progressDelta = afterResponse.progress - beforeResponse.progress;
    final double safetyDelta = afterResponse.safety - beforeResponse.safety;
    final double aggressionDelta =
        afterResponse.aggression - beforeResponse.aggression;
    final Map<String, double> deltas = <String, double>{
      'progress': progressDelta,
      'safety': safetyDelta,
      'aggression': aggressionDelta,
    };
    final List<MapEntry<String, double>> sorted = deltas.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final MapEntry<String, double> dominant = sorted.first;
    if (dominant.value.abs() < 0.02) {
      return 'Weighting remains mostly stable while I gather more evidence.';
    }
    final String direction = dominant.value > 0 ? 'increasing' : 'reducing';
    return 'I am $direction emphasis on ${dominant.key} based on your recent move pattern.';
  }

  String _buildDebugDetails({
    required PlayerTendencies beforeBeliefs,
    required PlayerTendencies afterBeliefs,
    required ValueWeights beforeResponse,
    required ValueWeights afterResponse,
  }) {
    return 'Belief shift: '
        'progress ${_formatArrow(afterBeliefs.progress - beforeBeliefs.progress)}, '
        'safety ${_formatArrow(afterBeliefs.safety - beforeBeliefs.safety)}, '
        'aggression ${_formatArrow(afterBeliefs.aggression - beforeBeliefs.aggression)}. '
        'Response shift: '
        'progress ${_formatArrow(afterResponse.progress - beforeResponse.progress)}, '
        'safety ${_formatArrow(afterResponse.safety - beforeResponse.safety)}, '
        'aggression ${_formatArrow(afterResponse.aggression - beforeResponse.aggression)}.';
  }

  String _formatArrow(double delta) {
    const double epsilon = 0.0001;
    if (delta > epsilon) {
      return '↑ ${_formatPercent(delta)}';
    }
    if (delta < -epsilon) {
      return '↓ ${_formatPercent(delta.abs())}';
    }
    return '→ 0.0%';
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
