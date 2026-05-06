import 'dart:math';

class BayesianLearningModel {
  final Map<_PlayerTrait, _BetaPosterior> _playerPosteriors;
  final _BetaPosterior _responseEfficacyPosterior;

  BayesianLearningModel()
      : _playerPosteriors = {
          _PlayerTrait.progress: _BetaPosterior(),
          _PlayerTrait.safety: _BetaPosterior(),
          _PlayerTrait.aggression: _BetaPosterior(),
        },
        _responseEfficacyPosterior = _BetaPosterior();

  void reset() {
    for (final posterior in _playerPosteriors.values) {
      posterior.reset();
    }
    _responseEfficacyPosterior.reset();
  }

  void registerPlayerEvidence({
    required double progressSuccess,
    required double progressFailure,
    required double safetySuccess,
    required double safetyFailure,
    required double aggressionSuccess,
    required double aggressionFailure,
  }) {
    _playerPosteriors[_PlayerTrait.progress]!.update(
      success: progressSuccess,
      failure: progressFailure,
    );
    _playerPosteriors[_PlayerTrait.safety]!.update(
      success: safetySuccess,
      failure: safetyFailure,
    );
    _playerPosteriors[_PlayerTrait.aggression]!.update(
      success: aggressionSuccess,
      failure: aggressionFailure,
    );
  }

  void registerResponseOutcome({
    required double success,
    required double failure,
  }) {
    _responseEfficacyPosterior.update(success: success, failure: failure);
  }

  PlayerTendencies inferPlayerTendencies() {
    return PlayerTendencies(
      progress: _playerPosteriors[_PlayerTrait.progress]!.mean,
      safety: _playerPosteriors[_PlayerTrait.safety]!.mean,
      aggression: _playerPosteriors[_PlayerTrait.aggression]!.mean,
      confidence: _mean(
        _playerPosteriors[_PlayerTrait.progress]!.certainty,
        _playerPosteriors[_PlayerTrait.safety]!.certainty,
        _playerPosteriors[_PlayerTrait.aggression]!.certainty,
      ),
    );
  }

  double get responseEfficacy => _responseEfficacyPosterior.mean;

  double _mean(double a, double b, double c) {
    return (a + b + c) / 3;
  }
}

enum _PlayerTrait {
  progress,
  safety,
  aggression,
}

class _BetaPosterior {
  static const double _priorAlpha = 2.0;
  static const double _priorBeta = 2.0;
  static const double _evidenceFloor = 0.05;
  static const double _evidenceGain = 1.18;

  double _alpha = _priorAlpha;
  double _beta = _priorBeta;

  void reset() {
    _alpha = _priorAlpha;
    _beta = _priorBeta;
  }

  void update({
    required double success,
    required double failure,
  }) {
    _alpha += max(success * _evidenceGain, _evidenceFloor);
    _beta += max(failure * _evidenceGain, _evidenceFloor);
  }

  double get mean => _alpha / (_alpha + _beta);

  double get variance {
    final double denominator = (_alpha + _beta);
    if (denominator <= 0) {
      return 0;
    }
    final double value = (_alpha * _beta) /
        (pow(denominator, 2) * (denominator + 1)).toDouble();
    return value;
  }

  double get certainty {
    final double stdDev = sqrt(variance);
    return (1 - (stdDev * 2)).clamp(0, 1).toDouble();
  }
}

class PlayerTendencies {
  final double progress;
  final double safety;
  final double aggression;
  final double confidence;

  const PlayerTendencies({
    required this.progress,
    required this.safety,
    required this.aggression,
    required this.confidence,
  });
}

