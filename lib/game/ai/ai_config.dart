import 'package:trgou/game/ai/value_weights.dart';

enum AIStyleOverride {
  random,
  aggressive,
  defensive,
  progressive,
  bayesian,
}

class AiConfig {
  final ValueWeights baseWeights;
  final AIStyleOverride? styleOverride;

  const AiConfig({
    this.baseWeights = const ValueWeights(
      progress: 1.0,
      safety: 1.0,
      aggression: 1.0),
    this.styleOverride,
  });

  AiConfig copyWith({
    ValueWeights? baseWeights,
    Object? styleOverride = _unset,
  }) {
    return AiConfig(
      baseWeights: baseWeights ?? this.baseWeights,
      styleOverride: styleOverride == _unset
          ? this.styleOverride
          : styleOverride as AIStyleOverride?,
    );
  }

  static const Object _unset = Object();
}
