import 'dart:math' as math;

import 'package:trgou/game/ai/ai_adaptation_policy.dart';
import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/ai/bayesian_learning_model.dart';
import 'package:trgou/game/ai/ai_explanation_builder.dart';
import 'package:trgou/game/ai/move_evaluation.dart';
import 'package:trgou/game/ai/move_evaluator.dart';
import 'package:trgou/game/ai/value_weights.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/random/deterministic_random.dart';

class AIEngine {
  static const double _similarMoveSpreadThreshold = 0.15;

  final MoveEvaluator _moveEvaluator;
  final AiExplanationBuilder _explanationBuilder;
  final BayesianLearningModel _bayesianLearningModel;
  final AiAdaptationPolicy _adaptationPolicy;
  final DeterministicRandom _random;
  AiConfig config;

  AIEngine({
    MoveEvaluator? moveEvaluator,
    AiExplanationBuilder? explanationBuilder,
    BayesianLearningModel? bayesianLearningModel,
    AiAdaptationPolicy? adaptationPolicy,
    DeterministicRandom? random,
    AiConfig? config,
  }) : _moveEvaluator = moveEvaluator ?? MoveEvaluator(),
       _explanationBuilder = explanationBuilder ?? const AiExplanationBuilder(),
       _bayesianLearningModel =
           bayesianLearningModel ?? BayesianLearningModel(),
       _adaptationPolicy = adaptationPolicy ?? const AiAdaptationPolicy(),
       _random =
           random ??
           DeterministicRandom(seed: DeterministicRandom.generateSeed()),
       config = config ?? const AiConfig();

  List<MoveEvaluation> evaluateMoves(GameState state, List<MoveOption> moves) {
    final ValueWeights activeWeights = _resolveActiveWeights();
    return moves
        .map((move) => _moveEvaluator.evaluateMove(state, move, activeWeights))
        .toList();
  }

  AiDecisionTrace? pickBestMoveTrace(GameState state, List<MoveOption> moves) {
    if (moves.isEmpty) {
      return null;
    }

    final ValueWeights activeWeights = _resolveActiveWeights();
    final PlayerTendencies? tendencies = config.styleOverride == AIStyleOverride.bayesian
        ? _bayesianLearningModel.inferPlayerTendencies()
        : null;
    final double? responseEfficacy = config.styleOverride == AIStyleOverride.bayesian
        ? _bayesianLearningModel.responseEfficacy
        : null;

    if (config.styleOverride == AIStyleOverride.random) {
      final MoveOption randomMove = moves[_random.nextInt(moves.length)];
      final MoveEvaluation evaluation = _moveEvaluator.evaluateMove(
        state,
        randomMove,
        activeWeights,
      );
      final MoveEvaluation selectedWithExplanation = _withExplanation(
        evaluation,
        _explanationBuilder.buildSelectionExplanation(
          selected: evaluation,
          allEvaluations: <MoveEvaluation>[evaluation],
          isOpeningPosition: _isOpeningPosition(state),
          areMovesSimilar: true,
        ),
      );
      return AiDecisionTrace(
        selectedEvaluation: selectedWithExplanation,
        candidateEvaluations: <MoveEvaluation>[selectedWithExplanation],
        activeWeights: activeWeights,
        inferredPlayerTendencies: tendencies,
        responseEfficacy: responseEfficacy,
      );
    }

    final List<MoveEvaluation> evaluations = moves
        .map((move) => _moveEvaluator.evaluateMove(state, move, activeWeights))
        .toList();
    MoveEvaluation best = evaluations.first;

    for (int i = 1; i < evaluations.length; i++) {
      final MoveEvaluation candidate = evaluations[i];
      if (_isBetter(candidate, best)) {
        best = candidate;
      }
    }

    final bool isOpeningPosition = _isOpeningPosition(state);
    final bool areMovesSimilar = _areMovesFairlyEqual(evaluations);
    final String explanation = _explanationBuilder.buildSelectionExplanation(
      selected: best,
      allEvaluations: evaluations,
      isOpeningPosition: isOpeningPosition,
      areMovesSimilar: areMovesSimilar,
    );
    final MoveEvaluation selectedWithExplanation = _withExplanation(
      best,
      explanation,
    );
    final List<MoveEvaluation> candidateEvaluations = evaluations
        .map(
          (MoveEvaluation evaluation) => evaluation.move.pieceId == best.move.pieceId &&
                  evaluation.move.fromTileId == best.move.fromTileId &&
                  evaluation.move.toTileId == best.move.toTileId
              ? selectedWithExplanation
              : evaluation,
        )
        .toList();

    return AiDecisionTrace(
      selectedEvaluation: selectedWithExplanation,
      candidateEvaluations: candidateEvaluations,
      activeWeights: activeWeights,
      inferredPlayerTendencies: tendencies,
      responseEfficacy: responseEfficacy,
    );
  }

  MoveEvaluation? pickBestMove(GameState state, List<MoveOption> moves) {
    final AiDecisionTrace? trace = pickBestMoveTrace(state, moves);
    return trace?.selectedEvaluation;
  }

  ValueWeights _resolveActiveWeights() {
    final AIStyleOverride? override = config.styleOverride;
    if (override == null) {
      return config.baseWeights;
    }

    switch (override) {
      case AIStyleOverride.random:
        return config.baseWeights;
      case AIStyleOverride.aggressive:
        return const ValueWeights(progress: 0.9, safety: 0.5, aggression: 1.8);
      case AIStyleOverride.defensive:
        return const ValueWeights(progress: 0.8, safety: 1.8, aggression: 0.5);
      case AIStyleOverride.progressive:
        return const ValueWeights(progress: 1.8, safety: 0.9, aggression: 0.8);
      case AIStyleOverride.bayesian:
        final PlayerTendencies tendencies = _bayesianLearningModel
            .inferPlayerTendencies();
        final ValueWeights adapted = _adaptationPolicy.resolveCounterWeights(
          baseWeights: config.baseWeights,
          playerTendencies: tendencies,
          responseEfficacy: _bayesianLearningModel.responseEfficacy,
        );
        final ValueWeights boosted = ValueWeights(
          progress: adapted.progress * 1.072,
          safety: adapted.safety * 1.026,
          aggression: adapted.aggression * 1.098,
        );
        return ValueWeights(
          progress: math.max(boosted.progress, config.baseWeights.progress),
          safety: math.max(boosted.safety, config.baseWeights.safety),
          aggression: math.max(
            boosted.aggression,
            config.baseWeights.aggression,
          ),
        );
    }
  }

  void resetBayesianLearning() {
    _bayesianLearningModel.reset();
  }

  BayesianLearningDiagnostics? get bayesianLearningDiagnostics {
    if (config.styleOverride != AIStyleOverride.bayesian) {
      return null;
    }
    return BayesianLearningDiagnostics(
      inferredPlayerTendencies: _bayesianLearningModel.inferPlayerTendencies(),
      responseEfficacy: _bayesianLearningModel.responseEfficacy,
      adaptedWeights: _resolveActiveWeights(),
    );
  }

  void registerBayesianOutcome({
    required MoveEvaluation selectedEvaluation,
    required int captureCount,
    required bool landedOnRosette,
    required bool wonGame,
  }) {
    if (config.styleOverride != AIStyleOverride.bayesian) {
      return;
    }

    final double normalizedProgress = _normalize(
      selectedEvaluation.progressScore,
    );
    final double normalizedSafety = _normalize(selectedEvaluation.safetyScore);
    final double normalizedAggression = _normalize(
      selectedEvaluation.aggressionScore,
    );

    final double progressSuccess = _clamp01(
      (normalizedProgress * 0.65) + (wonGame ? 0.35 : 0),
    );
    final double progressFailure = _clamp01(
      ((1 - normalizedProgress) * 0.6) + (wonGame ? 0 : 0.25),
    );

    final double safetySuccess = _clamp01(
      (normalizedSafety * 0.55) + (landedOnRosette ? 0.45 : 0),
    );
    final double safetyFailure = _clamp01(
      ((1 - normalizedSafety) * 0.7) + (captureCount > 0 ? 0 : 0.2),
    );

    final double aggressionSuccess = _clamp01(
      (normalizedAggression * 0.5) + (captureCount > 0 ? 0.5 : 0),
    );
    final double aggressionFailure = _clamp01(
      ((1 - normalizedAggression) * 0.65) + (captureCount > 0 ? 0 : 0.25),
    );

    final double combinedSuccess = _clamp01(
      (progressSuccess * 0.4) +
          (safetySuccess * 0.3) +
          (aggressionSuccess * 0.3),
    );
    final double combinedFailure = _clamp01(
      (progressFailure * 0.4) +
          (safetyFailure * 0.3) +
          (aggressionFailure * 0.3),
    );
    _bayesianLearningModel.registerResponseOutcome(
      success: combinedSuccess,
      failure: combinedFailure,
    );
  }

  OpponentMoveCommentary? registerOpponentMoveAndComment({
    required GameState stateBeforeMove,
    required MoveOption opponentMove,
    required int captureCount,
    required bool landedOnRosette,
    required bool reachedFinish,
  }) {
    if (config.styleOverride != AIStyleOverride.bayesian) {
      return null;
    }

    final PlayerTendencies beforeBeliefs = _bayesianLearningModel
        .inferPlayerTendencies();
    final ValueWeights beforeResponse = _resolveActiveWeights();
    final MoveEvaluation observed = _moveEvaluator.evaluateMove(
      stateBeforeMove,
      opponentMove,
      const ValueWeights(progress: 1.0, safety: 1.0, aggression: 1.0),
    );

    final double normalizedProgress = _normalize(observed.progressScore);
    final double normalizedSafety = _normalize(observed.safetyScore);
    final double normalizedAggression = _normalize(observed.aggressionScore);

    final double progressSuccess = _clamp01(
      (normalizedProgress * 0.55) + (reachedFinish ? 0.45 : 0),
    );
    final double progressFailure = _clamp01((1 - normalizedProgress) * 0.5);

    final double safetySuccess = _clamp01(
      (normalizedSafety * 0.45) + (landedOnRosette ? 0.35 : 0),
    );
    final double safetyFailure = _clamp01(
      ((1 - normalizedSafety) * 0.5) + (captureCount > 0 ? 0.35 : 0),
    );

    final double aggressionSuccess = _clamp01(
      (normalizedAggression * 0.5) + (captureCount > 0 ? 0.45 : 0),
    );
    final double aggressionFailure = _clamp01(
      ((1 - normalizedAggression) * 0.5) + (landedOnRosette ? 0.2 : 0),
    );

    _bayesianLearningModel.registerPlayerEvidence(
      progressSuccess: progressSuccess,
      progressFailure: progressFailure,
      safetySuccess: safetySuccess,
      safetyFailure: safetyFailure,
      aggressionSuccess: aggressionSuccess,
      aggressionFailure: aggressionFailure,
    );

    final PlayerTendencies afterBeliefs = _bayesianLearningModel
        .inferPlayerTendencies();
    final ValueWeights afterResponse = _resolveActiveWeights();
    final AdaptiveExplanationBundle explanationBundle = _explanationBuilder
        .buildAdaptiveBeliefExplanation(
          observed: observed,
          captureCount: captureCount,
          landedOnRosette: landedOnRosette,
          reachedFinish: reachedFinish,
          beforeBeliefs: beforeBeliefs,
          afterBeliefs: afterBeliefs,
          beforeResponse: beforeResponse,
          afterResponse: afterResponse,
        );

    return OpponentMoveCommentary(
      observedEvaluation: observed,
      explanation: explanationBundle.playerFacing,
      debugDetails: explanationBundle.debugDetails,
    );
  }

  bool _isBetter(MoveEvaluation candidate, MoveEvaluation currentBest) {
    if (candidate.totalScore != currentBest.totalScore) {
      return candidate.totalScore > currentBest.totalScore;
    }

    if (candidate.progressScore != currentBest.progressScore) {
      return candidate.progressScore > currentBest.progressScore;
    }

    return candidate.move.pieceId < currentBest.move.pieceId;
  }

  MoveEvaluation _withExplanation(
    MoveEvaluation evaluation,
    String explanation,
  ) {
    return MoveEvaluation(
      move: evaluation.move,
      progressScore: evaluation.progressScore,
      safetyScore: evaluation.safetyScore,
      aggressionScore: evaluation.aggressionScore,
      totalScore: evaluation.totalScore,
      explanation: explanation,
    );
  }

  bool _isOpeningPosition(GameState state) {
    bool foundCurrentPlayerPiece = false;
    for (final piece in state.pieces) {
      if (piece.player != state.currentPlayer) {
        continue;
      }
      foundCurrentPlayerPiece = true;
      if (piece.pathIndex != 0) {
        return false;
      }
    }

    return foundCurrentPlayerPiece;
  }

  bool _areMovesFairlyEqual(List<MoveEvaluation> evaluations) {
    if (evaluations.length <= 1) {
      return true;
    }

    double minScore = evaluations.first.totalScore;
    double maxScore = evaluations.first.totalScore;
    for (final evaluation in evaluations) {
      if (evaluation.totalScore < minScore) {
        minScore = evaluation.totalScore;
      }
      if (evaluation.totalScore > maxScore) {
        maxScore = evaluation.totalScore;
      }
    }

    return (maxScore - minScore) <= _similarMoveSpreadThreshold;
  }

  double _normalize(double score) {
    return _clamp01((score + 1) / 2);
  }

  double _clamp01(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}

class BayesianLearningDiagnostics {
  final PlayerTendencies inferredPlayerTendencies;
  final double responseEfficacy;
  final ValueWeights adaptedWeights;

  const BayesianLearningDiagnostics({
    required this.inferredPlayerTendencies,
    required this.responseEfficacy,
    required this.adaptedWeights,
  });
}

class OpponentMoveCommentary {
  final MoveEvaluation observedEvaluation;
  final String explanation;
  final String debugDetails;

  const OpponentMoveCommentary({
    required this.observedEvaluation,
    required this.explanation,
    required this.debugDetails,
  });
}

class AiDecisionTrace {
  final MoveEvaluation selectedEvaluation;
  final List<MoveEvaluation> candidateEvaluations;
  final ValueWeights activeWeights;
  final PlayerTendencies? inferredPlayerTendencies;
  final double? responseEfficacy;

  const AiDecisionTrace({
    required this.selectedEvaluation,
    required this.candidateEvaluations,
    required this.activeWeights,
    required this.inferredPlayerTendencies,
    required this.responseEfficacy,
  });
}
