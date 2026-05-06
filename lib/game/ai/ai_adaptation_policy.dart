import 'package:trgou/game/ai/bayesian_learning_model.dart';
import 'package:trgou/game/ai/value_weights.dart';

class AiAdaptationPolicy {
  static const double _weightFloor = 0.55;
  static const double _weightCeiling = 2.45;

  const AiAdaptationPolicy();

  ValueWeights resolveCounterWeights({
    required ValueWeights baseWeights,
    required PlayerTendencies playerTendencies,
    required double responseEfficacy,
  }) {
    final double confidenceFactor =
        0.72 + (playerTendencies.confidence * 0.95);
    final double efficacyFactor = 0.7 + (responseEfficacy * 0.75);
    final double adaptationStrength = confidenceFactor * efficacyFactor;

    final double safetyCounterSignal =
        (playerTendencies.aggression * 0.55) +
        (playerTendencies.progress * 0.225) +
        (playerTendencies.safety * 0.225);
    final double aggressionCounterSignal =
        (playerTendencies.safety * 0.55) +
        (playerTendencies.progress * 0.225) +
        (playerTendencies.aggression * 0.225);
    final double progressCounterSignal =
        (playerTendencies.progress * 0.5) +
        (playerTendencies.safety * 0.25) +
        (playerTendencies.aggression * 0.25);

    ValueWeights weights = ValueWeights(
      progress: _scaled(
        base: baseWeights.progress,
        signal: progressCounterSignal,
        adaptationStrength: adaptationStrength,
      ),
      safety: _scaled(
        base: baseWeights.safety,
        signal: safetyCounterSignal,
        adaptationStrength: adaptationStrength,
      ),
      aggression: _scaled(
        base: baseWeights.aggression,
        signal: aggressionCounterSignal,
        adaptationStrength: adaptationStrength,
      ),
    );

    if (playerTendencies.progress + playerTendencies.aggression < 1.06) {
      weights = ValueWeights(
        progress: (weights.progress * 1.055).clamp(_weightFloor, _weightCeiling),
        safety: weights.safety,
        aggression: (weights.aggression * 1.04).clamp(_weightFloor, _weightCeiling),
      );
    }

    return weights;
  }

  double _scaled({
    required double base,
    required double signal,
    required double adaptationStrength,
  }) {
    final double modifier =
        1.0 + ((signal - 0.5) * adaptationStrength * 0.92);
    return (base * modifier).clamp(_weightFloor, _weightCeiling).toDouble();
  }
}
