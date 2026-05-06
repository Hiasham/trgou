import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/app_settings/app_settings_provider.dart';
import 'package:trgou/game/ai/ai_engine.dart';
import 'package:trgou/game/ai/ai_explanation.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/game/widgets/board_widget.dart';
import 'package:trgou/game/widgets/roll_widget.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isWinnerDialogOpen = false;
  Timer? _aiExplanationHideTimer;
  static const Duration _aiExplanationDisplayDuration = Duration(seconds: 7);
  static const Duration _aiExplanationFadeDuration = Duration(
    milliseconds: 500,
  );
  bool _isAiExplanationVisible = false;

  @override
  void dispose() {
    _aiExplanationHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(gameStateProvider.notifier);
    final bool isAiMode = gameState.gameMode == GameMode.aiOpponent;
    final bool debugEnabled = settings.debugEnabled;
    final String currentPlayerLabel = _playerTopText(gameState.currentPlayer);
    final bool hasAiExplanation =
        isAiMode && gameState.latestAiExplanation != null;
    final String topText;
    if (gameState.isDeterminingFirstPlayer) {
      final int? p1Roll = gameState.openingRollPlayerOne;
      final int? p2Roll = gameState.openingRollPlayerTwo;
      if (p1Roll == null || p2Roll == null) {
        topText =
            'Opening roll-off: Player $currentPlayerLabel, roll to decide who starts.';
      } else {
        topText =
            'Opening roll-off tied at $p1Roll-$p2Roll. Rolling again...';
      }
    } else {
      topText = hasAiExplanation
          ? gameState.latestAiExplanation!.explanation
          : "Player $currentPlayerLabel's turn";
    }

    ref.listen<Player?>(gameStateProvider.select((state) => state.winner), (
      previous,
      next,
    ) {
      if (next != null && !_isWinnerDialogOpen) {
        debugPrint(
          '[GameScreen] Winner detected: $next. Showing winner dialog.',
        );
        _isWinnerDialogOpen = true;
        _showWinnerDialog(next);
      }
    });

    ref.listen<AIExplanation?>(
      gameStateProvider.select((state) => state.latestAiExplanation),
      (previous, next) {
        if (!mounted) {
          return;
        }

        _aiExplanationHideTimer?.cancel();
        if (next == null) {
          if (_isAiExplanationVisible) {
            setState(() {
              _isAiExplanationVisible = false;
            });
          }
          return;
        }

        setState(() {
          _isAiExplanationVisible = true;
        });

        _aiExplanationHideTimer = Timer(_aiExplanationDisplayDuration, () {
          if (!mounted) {
            return;
          }
          setState(() {
            _isAiExplanationVisible = false;
          });
          _aiExplanationHideTimer = Timer(_aiExplanationFadeDuration, () {
            if (!mounted) {
              return;
            }
            final AIExplanation? latestExplanation = ref
                .read(gameStateProvider)
                .latestAiExplanation;
            if (_isSameExplanation(latestExplanation, next)) {
              controller.clearLatestAiExplanation();
            }
          });
        });
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _finishActiveExplanationTimer();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: debugEnabled
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 24).clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isAiMode && !gameState.isDeterminingFirstPlayer)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              topText,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          height: 800,
                          width: 320,
                          child: Stack(
                            children: [
                              const Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 270,
                                  height: 800,
                                  child: BoardWidget(),
                                ),
                              ),
                              if (hasAiExplanation)
                                Positioned(
                                  top: 38,
                                  left: 8,
                                  right: 8,
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: AnimatedOpacity(
                                      opacity: _isAiExplanationVisible ? 1 : 0,
                                      duration: _aiExplanationFadeDuration,
                                      curve: Curves.easeOut,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(999),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            topText,
                                            style: Theme.of(context).textTheme.bodySmall
                                                ?.copyWith(color: Colors.black),
                                            textAlign: TextAlign.center,
                                            softWrap: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -50),
                          child: const RollWidget(),
                        ),
                        if (debugEnabled) ...[
                          const SizedBox(height: 8),
                          _buildDebugPanel(context, gameState),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _finishActiveExplanationTimer() {
    final AIExplanation? activeExplanation = ref
        .read(gameStateProvider)
        .latestAiExplanation;
    if (activeExplanation == null) {
      return;
    }

    _aiExplanationHideTimer?.cancel();
    if (_isAiExplanationVisible) {
      setState(() {
        _isAiExplanationVisible = false;
      });
    }

    _aiExplanationHideTimer = Timer(_aiExplanationFadeDuration, () {
      if (!mounted) {
        return;
      }
      final AIExplanation? latestExplanation = ref
          .read(gameStateProvider)
          .latestAiExplanation;
      if (_isSameExplanation(latestExplanation, activeExplanation)) {
        ref.read(gameStateProvider.notifier).clearLatestAiExplanation();
      }
    });
  }

  Future<void> _showWinnerDialog(Player winner) async {
    final String winnerLabel = _playerTopText(winner);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Match Finished'),
          content: Text('Player $winnerLabel wins!'),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('[GameScreen] Winner dialog action: Exit to Menu.');
                final mode = ref.read(gameStateProvider).gameMode;
                ref.read(gameStateProvider.notifier).reset(mode: mode);
                Navigator.of(dialogContext).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Exit to Menu'),
            ),
            FilledButton(
              onPressed: () {
                debugPrint('[GameScreen] Winner dialog action: Replay.');
                final mode = ref.read(gameStateProvider).gameMode;
                final int seed = ref.read(gameStateProvider).matchSeed;
                ref
                    .read(gameStateProvider.notifier)
                    .reset(mode: mode, seed: seed);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Replay'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      _isWinnerDialogOpen = false;
    }
  }

  String _playerTopText(Player player) {
    switch (player) {
      case Player.playerOne:
        return '1';
      case Player.playerTwo:
        return '2';
    }
  }

  bool _isSameExplanation(AIExplanation? a, AIExplanation? b) {
    if (a == null || b == null) {
      return false;
    }

    return a.pieceId == b.pieceId &&
        a.fromTileId == b.fromTileId &&
        a.toTileId == b.toTileId &&
        a.explanation == b.explanation;
  }

  Widget _buildDebugPanel(BuildContext context, GameState gameState) {
    final String modeLabel = switch (gameState.gameMode) {
      GameMode.hotseat => 'Hotseat',
      GameMode.aiOpponent => 'AI Opponent',
    };
    final String currentPlayerLabel = _playerTopText(gameState.currentPlayer);
    final String winnerLabel = gameState.winner == null
        ? '-'
        : _playerTopText(gameState.winner!);
    final AIExplanation? latest = gameState.latestAiExplanation;
    final BayesianLearningDiagnostics? bayesianDiag =
        ref.read(gameStateProvider.notifier).bayesianLearningDiagnostics;

    return Container(
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodySmall!.copyWith(color: Colors.white70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('debugging stuff', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 6),
            Text('Mode: $modeLabel'),
            Text('Current player: P$currentPlayerLabel'),
            Text('Winner: ${winnerLabel == '-' ? '-' : 'P$winnerLabel'}'),
            Text('Selected tile: ${gameState.selectedTileId ?? '-'}'),
            Text('Dice roll: ${gameState.diceRoll ?? '-'}'),
            Text(
              'Seed: ${gameState.matchSeed} | RNG calls: ${gameState.randomCallCount}',
            ),
            if (bayesianDiag != null) ...[
              const SizedBox(height: 4),
              Text(
                'Bayesian beliefs: prog=${bayesianDiag.inferredPlayerTendencies.progress.toStringAsFixed(2)} '
                'safe=${bayesianDiag.inferredPlayerTendencies.safety.toStringAsFixed(2)} '
                'aggr=${bayesianDiag.inferredPlayerTendencies.aggression.toStringAsFixed(2)} '
                'conf=${bayesianDiag.inferredPlayerTendencies.confidence.toStringAsFixed(2)}',
              ),
              Text(
                'Bayesian response efficacy: '
                '${bayesianDiag.responseEfficacy.toStringAsFixed(2)}',
              ),
              Text(
                'Bayesian weights: prog=${bayesianDiag.adaptedWeights.progress.toStringAsFixed(2)} '
                'safe=${bayesianDiag.adaptedWeights.safety.toStringAsFixed(2)} '
                'aggr=${bayesianDiag.adaptedWeights.aggression.toStringAsFixed(2)}',
              ),
            ],
            if (latest?.debugDetails != null) ...[
              const SizedBox(height: 4),
              Text('AI debug: ${latest!.debugDetails}'),
            ],
          ],
        ),
      ),
    );
  }
}
