import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/app_settings/app_settings_provider.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';

class RollWidget extends ConsumerStatefulWidget {
  const RollWidget({
    super.key
  });

  @override
  ConsumerState<RollWidget> createState() => _RollWidgetState();
}

class _RollWidgetState extends ConsumerState<RollWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9, end: 9), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9, end: -7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final bool isAiTurn = gameState.gameMode == GameMode.aiOpponent &&
        gameState.currentPlayer == Player.playerTwo;
    final bool isOpeningRollOff = gameState.isDeterminingFirstPlayer;
    final bool debugEnabled = ref.watch(appSettingsProvider).debugEnabled;
    final bool canRoll = gameState.diceRoll == null && !isAiTurn;

    ref.listen<int>(
      gameStateProvider.select((state) => state.rollShakeCounter),
      (previous, next) {
        if (previous != null && previous != next) {
          _shakeController.forward(from: 0);
        }
      },
    );

    return AnimatedBuilder(
      animation: _shakeAnimation,
      child: _buildContent(
        canRoll: canRoll,
        diceRoll: gameState.diceRoll,
        isAiTurn: isAiTurn,
        debugEnabled: debugEnabled,
        isOpeningRollOff: isOpeningRollOff,
        openingRollPlayerOne: gameState.openingRollPlayerOne,
        openingRollPlayerTwo: gameState.openingRollPlayerTwo,
      ),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
    );
  }

  Widget _buildContent({
    required bool canRoll,
    required int? diceRoll,
    required bool isAiTurn,
    required bool debugEnabled,
    required bool isOpeningRollOff,
    required int? openingRollPlayerOne,
    required int? openingRollPlayerTwo,
  }) {
    final String buttonLabel;
    if (isAiTurn) {
      buttonLabel = 'AI Thinking...';
    } else if (isOpeningRollOff) {
      buttonLabel = 'Roll To Decide First Turn';
    } else if (diceRoll == null) {
      buttonLabel = 'Roll';
    } else {
      buttonLabel = 'Roll: $diceRoll';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            elevation: 6,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: canRoll
              ? () {
                  ref.read(gameStateProvider.notifier).rollDice();
                }
              : null,
          child: Text(buttonLabel),
        ),
        if (isOpeningRollOff)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Roll-off: P1 ${openingRollPlayerOne ?? '-'} | '
              'P2 ${openingRollPlayerTwo ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (debugEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'debug: canRoll=$canRoll, aiTurn=$isAiTurn, '
              'opening=$isOpeningRollOff, roll=${diceRoll ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}