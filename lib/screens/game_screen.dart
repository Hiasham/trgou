import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/persistence/game_state_persistence.dart';
import 'package:trgou/game/ai/bot_style.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/game/widgets/board_widget.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);

    ref.listen(gameControllerProvider, (prev, next) {
      final isBotTurnNoRoll = next.gameMode == GameMode.bot &&
          next.currentPlayer == Player.two &&
          next.lastRoll == null;
      final isBotTurnWithRoll = next.gameMode == GameMode.bot &&
          next.currentPlayer == Player.two &&
          next.lastRoll != null;
      final wasBotTurnNoRoll = prev != null &&
          prev.gameMode == GameMode.bot &&
          prev.currentPlayer == Player.two &&
          prev.lastRoll == null;

      if (isBotTurnNoRoll) {
        final wasNotBotTurnNoRoll = prev == null ||
            prev.gameMode != GameMode.bot ||
            prev.currentPlayer != Player.two ||
            prev.lastRoll != null;
        if (wasNotBotTurnNoRoll) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!context.mounted) return;
            ref.read(gameControllerProvider.notifier).roll();
          });
        }
        return;
      }

      if (isBotTurnWithRoll && wasBotTurnNoRoll) {
        ref.read(botStrategyProvider.future).then((strategy) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!context.mounted) return;
            ref.read(gameControllerProvider.notifier).performBotMove(strategy);
          });
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await saveGameState(ref.read(gameControllerProvider));
        ref.invalidate(savedGameStateProvider);
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth * 0.72;
          final availableHeight = constraints.maxHeight * 0.72;
          const spacing = 8.0;

          final tileSizeFromWidth = (availableWidth - 2 * spacing) / 3;
          final tileSizeFromHeight = (availableHeight - 7 * spacing) / 8;
          final tileSize = tileSizeFromWidth < tileSizeFromHeight
              ? tileSizeFromWidth
              : tileSizeFromHeight;

          final isPlayer1Turn = gameState.currentPlayer == Player.one;
          final rightLabel = gameState.gameMode == GameMode.bot ? 'Bot' : 'Player 2';
          final clampedTileSize = tileSize.clamp(24.0, double.infinity);
          const cols = 3;
          final boardWidth = cols * clampedTileSize + (cols - 1) * spacing;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: boardWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Player 1', style: Theme.of(context).textTheme.labelLarge),
                      gameState.gameMode == GameMode.bot
                          ? const _BotLabel()
                          : Text(rightLabel, style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                BoardWidget(
                  tiles: gameState.tiles,
                  pieces: [
                    ...gameState.playerOnePieces,
                    ...gameState.playerTwoPieces,
                  ],
                  tileSize: clampedTileSize,
                  spacing: spacing,
                  currentPlayer: gameState.currentPlayer,
                  hasRoll: gameState.lastRoll != null,
                  onTileTap: (tileId) =>
                      ref.read(gameControllerProvider.notifier).movePiece(tileId),
                ),
                const SizedBox(height: 16),
                Text(
                  isPlayer1Turn ? "Player 1's turn" : "$rightLabel's turn",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (gameState.gameMode == GameMode.bot &&
                    !isPlayer1Turn &&
                    gameState.lastRoll != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bot rolled ${gameState.lastRoll!.value}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final canRoll = gameState.lastRoll == null &&
                        (gameState.gameMode != GameMode.bot ||
                            gameState.currentPlayer == Player.one);
                    return Opacity(
                      opacity: canRoll ? 1 : 0.5,
                      child: Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: canRoll
                              ? () =>
                                  ref.read(gameControllerProvider.notifier).roll()
                              : null,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            child: Text(
                              gameState.lastRoll != null
                                  ? 'Roll — ${gameState.lastRoll!.value}'
                                  : 'Roll',
                              style: Theme.of(context)
                                  .textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}

class _BotLabel extends ConsumerWidget {
  const _BotLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styleAsync = ref.watch(botStyleProvider);
    final styleName = styleAsync.valueOrNull?.name ?? 'Aggressive';
    final label = 'Bot (${styleName[0].toUpperCase()}${styleName.substring(1)})';

    return GestureDetector(
      onTap: () => _showBotStyleDialog(context, ref),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _showBotStyleDialog(BuildContext context, WidgetRef ref) async {
    final chosen = await showDialog<BotStyle>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Bot style'),
        children: [
          ListTile(
            title: const Text('Aggressive'),
            subtitle: const Text('Moves one piece across as fast as possible'),
            onTap: () => Navigator.of(context).pop(BotStyle.aggressive),
          ),
          ListTile(
            title: const Text('Defensive'),
            subtitle: const Text('Gets as many pieces on the board as early as possible'),
            onTap: () => Navigator.of(context).pop(BotStyle.defensive),
          ),
        ],
      ),
    );
    if (chosen != null && context.mounted) {
      await saveBotStyle(chosen);
      ref.invalidate(botStyleProvider);
      ref.invalidate(botStrategyProvider);
    }
  }
}