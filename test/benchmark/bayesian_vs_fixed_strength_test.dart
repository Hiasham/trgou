import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/benchmark/headless_ai_match_simulator.dart';
import 'package:trgou/game/model/player.dart';

void main() {
  final List<int> kBenchmarkSeeds = List<int>.generate(200, (int i) => 42 + i);
  final List<int> kStyleSeeds = List<int>.generate(120, (int i) => 1042 + i);

  group('Bayesian vs fixed weights (same seeds)', () {
    test('aggregates complete and internally-consistent outcomes', () {
      final StrengthComparisonResult outcome =
          BayesianVsFixedStrengthBenchmark().run(seeds: kBenchmarkSeeds);

      expect(outcome.seedsTried, kBenchmarkSeeds.length);
      expect(
        outcome.fixedAiWins + outcome.playerWinsFixedWeights,
        kBenchmarkSeeds.length,
      );
      expect(
        outcome.bayesianAiWins + outcome.playerWinsBayesian,
        kBenchmarkSeeds.length,
      );
      expect(outcome.incompleteRuns, 0);

      expect(outcome.rows.length, kBenchmarkSeeds.length);
      for (final SingleSeedComparison row in outcome.rows) {
        expect(row.fixedWinner, isNotNull);
        expect(row.bayesianWinner, isNotNull);
        expect(row.fixedSteps, greaterThan(0));
        expect(row.bayesianSteps, greaterThan(0));
        expect(row.fixedTruncated, isFalse);
        expect(row.bayesianTruncated, isFalse);
      }

      final String summary = outcome.toString();
      expect(summary.contains('Bayesian vs fixed-weight model'), isTrue);

      final int winnerDeltas = _countWinnerDeltas(outcome);
      final int stepDeltas = _countStepDeltas(outcome);
      print(
        '\n$summary\n'
        'signal: winnerDeltas=$winnerDeltas, stepDeltas=$stepDeltas',
      );
    });

    test('re-running same seeds is deterministic', () {
      final StrengthComparisonResult first =
          BayesianVsFixedStrengthBenchmark().run(seeds: kBenchmarkSeeds);
      final StrengthComparisonResult second =
          BayesianVsFixedStrengthBenchmark().run(seeds: kBenchmarkSeeds);

      expect(second.seedsTried, first.seedsTried);
      expect(second.fixedAiWins, first.fixedAiWins);
      expect(second.bayesianAiWins, first.bayesianAiWins);
      expect(second.playerWinsFixedWeights, first.playerWinsFixedWeights);
      expect(second.playerWinsBayesian, first.playerWinsBayesian);
      expect(second.incompleteRuns, first.incompleteRuns);

      expect(second.rows, hasLength(first.rows.length));
      for (int i = 0; i < first.rows.length; i++) {
        final SingleSeedComparison a = first.rows[i];
        final SingleSeedComparison b = second.rows[i];
        expect(b.seed, a.seed);
        expect(b.fixedWinner, a.fixedWinner);
        expect(b.bayesianWinner, a.bayesianWinner);
        expect(b.fixedSteps, a.fixedSteps);
        expect(b.bayesianSteps, a.bayesianSteps);
        expect(b.fixedTruncated, a.fixedTruncated);
        expect(b.bayesianTruncated, a.bayesianTruncated);
      }
    });

    test('comparison produces observable model divergence signal', () {
      final StrengthComparisonResult outcome =
          BayesianVsFixedStrengthBenchmark().run(seeds: kBenchmarkSeeds);

      final int winnerDeltas = _countWinnerDeltas(outcome);
      final int stepDeltas = _countStepDeltas(outcome);
      final int totalSignal = winnerDeltas + stepDeltas;

      expect(totalSignal, greaterThan(0));
      expect(
        stepDeltas,
        greaterThan(0),
        reason:
            'No per-seed step deltas observed; benchmark may be too weak to '
            'show adaptive-vs-static behavioural differences.',
      );
    });

    test('style speed stats are available for dissertation reporting', () {
      final List<AIStyleOverride?> styles = <AIStyleOverride?>[
        null,
        AIStyleOverride.bayesian,
        AIStyleOverride.aggressive,
        AIStyleOverride.defensive,
        AIStyleOverride.progressive,
      ];

      final List<StyleSpeedStats> allStats = styles
          .map((AIStyleOverride? style) {
            return _runStyleStats(style: style, seeds: kStyleSeeds);
          })
          .toList();

      for (final StyleSpeedStats stats in allStats) {
        expect(stats.seedsTried, kStyleSeeds.length);
        expect(stats.incompleteRuns, 0);
        expect(stats.aiWins + stats.playerWins, kStyleSeeds.length);
        expect(stats.meanStepsAllGames, greaterThan(0));
      }

      final String report = _buildStyleReport(allStats);
      expect(report.contains('AI style speed report'), isTrue);
      print('\n$report');
    });
  });
}

int _countWinnerDeltas(StrengthComparisonResult result) {
  int count = 0;
  for (final SingleSeedComparison row in result.rows) {
    if (row.fixedWinner != row.bayesianWinner) {
      count++;
    }
  }
  return count;
}

int _countStepDeltas(StrengthComparisonResult result) {
  int count = 0;
  for (final SingleSeedComparison row in result.rows) {
    if (row.fixedSteps != row.bayesianSteps) {
      count++;
    }
  }
  return count;
}

StyleSpeedStats _runStyleStats({
  required AIStyleOverride? style,
  required List<int> seeds,
}) {
  int aiWins = 0;
  int playerWins = 0;
  int incompleteRuns = 0;
  int totalSteps = 0;
  int totalStepsInAiWins = 0;
  int totalStepsInPlayerWins = 0;
  final List<int> aiWinSteps = <int>[];

  for (final int seed in seeds) {
    final HeadlessMatchResult result = HeadlessAiMatchSimulator(
      aiConfig: AiConfig(styleOverride: style),
      matchSeed: seed,
    ).runToCompletion();

    totalSteps += result.steps;
    if (result.truncated) {
      incompleteRuns++;
      continue;
    }

    if (result.winner == Player.playerTwo) {
      aiWins++;
      totalStepsInAiWins += result.steps;
      aiWinSteps.add(result.steps);
    } else if (result.winner == Player.playerOne) {
      playerWins++;
      totalStepsInPlayerWins += result.steps;
    }
  }

  return StyleSpeedStats(
    style: style,
    seedsTried: seeds.length,
    aiWins: aiWins,
    playerWins: playerWins,
    incompleteRuns: incompleteRuns,
    meanStepsAllGames: _safeMean(totalSteps, seeds.length),
    meanStepsWhenAiWon: _safeMean(totalStepsInAiWins, aiWins),
    meanStepsWhenPlayerWon: _safeMean(totalStepsInPlayerWins, playerWins),
    medianStepsWhenAiWon: _median(aiWinSteps),
  );
}

double _safeMean(int total, int count) {
  if (count <= 0) {
    return 0;
  }
  return total / count;
}

double _median(List<int> values) {
  if (values.isEmpty) {
    return 0;
  }
  final List<int> sorted = List<int>.from(values)..sort();
  final int mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid].toDouble();
  }
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

String _buildStyleReport(List<StyleSpeedStats> stats) {
  final StringBuffer b = StringBuffer()
    ..writeln('AI style speed report (P2 AI vs deterministic P1)')
    ..writeln('seeds per style=${stats.first.seedsTried}')
    ..writeln(
      'columns: style | aiWins | playerWins | meanStepsAll | '
      'meanStepsWhenAiWon | medianStepsWhenAiWon | meanStepsWhenPlayerWon',
    )
    ..writeln('---');

  for (final StyleSpeedStats s in stats) {
    b.writeln(
      '${s.styleLabel} | ${s.aiWins} | ${s.playerWins} | '
      '${s.meanStepsAllGames.toStringAsFixed(2)} | '
      '${s.meanStepsWhenAiWon.toStringAsFixed(2)} | '
      '${s.medianStepsWhenAiWon.toStringAsFixed(1)} | '
      '${s.meanStepsWhenPlayerWon.toStringAsFixed(2)}',
    );
  }
  return b.toString();
}

class StyleSpeedStats {
  const StyleSpeedStats({
    required this.style,
    required this.seedsTried,
    required this.aiWins,
    required this.playerWins,
    required this.incompleteRuns,
    required this.meanStepsAllGames,
    required this.meanStepsWhenAiWon,
    required this.medianStepsWhenAiWon,
    required this.meanStepsWhenPlayerWon,
  });

  final AIStyleOverride? style;
  final int seedsTried;
  final int aiWins;
  final int playerWins;
  final int incompleteRuns;
  final double meanStepsAllGames;
  final double meanStepsWhenAiWon;
  final double medianStepsWhenAiWon;
  final double meanStepsWhenPlayerWon;

  String get styleLabel {
    if (style == null) {
      return 'default';
    }
    return style!.name;
  }
}
