import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/app_settings/app_settings_provider.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/game/widgets/piece_widget.dart';

class TileWidget extends ConsumerWidget {
  final Tile tile;
  
  const TileWidget({
    required this.tile,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final controller = ref.read(gameStateProvider.notifier);
    final currentPlayer = gameState.currentPlayer;
    final bool debugEnabled = ref.watch(appSettingsProvider).debugEnabled;
    final bool isSelected = gameState.selectedTileId == tile.tileId;
    final bool isPotentialMove =
        controller.getPotentialMoveTileId() == tile.tileId;
    final piecesOnTile = controller.getPiecesOnTile(tile.tileId);

    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {ref.read(gameStateProvider.notifier).onTileTapped(tile);},
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildTileVis(context, isSelected, isPotentialMove),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.94,
                          end: 1.0,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(_pieceSignature(piecesOnTile)),
                    child: _buildPiecesOverlay(
                      piecesOnTile,
                      currentPlayer,
                      debugEnabled,
                    ),
                  ),
                ),
              ),
              if (debugEnabled)
                Positioned(
                  top: 2,
                  left: 4,
                  child: _buildDebugTag(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileVis(
    BuildContext context,
    bool isSelected,
    bool isPotentialMove) {
    switch (tile.tileType) {
      case TileType.start:
        return _buildBlankTile(context, isSelected, isPotentialMove);

      case TileType.finish:
        return _buildBlankTile(context, isSelected, isPotentialMove);

      case TileType.basic:
        return _buildBasicTile(
          context,
          isSelected,
          isPotentialMove: isPotentialMove,
          child: null,
        );

      case TileType.rosette:
        return _buildBasicTile(
          context,
          isSelected,
          isPotentialMove: isPotentialMove,
          child: Center(
            child: Icon(
              Icons.local_florist_rounded,
              color: Theme.of(context).colorScheme.primaryContainer,
              size: 40,
            ),
          ),
        );
    }
  }

  Widget _buildBlankTile(
    BuildContext context,
    bool isSelected,
    bool isPotentialMove) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected || isPotentialMove
            ? _buildBorder(
                context,
                isSelected: isSelected,
                isPotentialMove: isPotentialMove,
              )
            : null,
      ),
    );
  }

  Widget _buildBasicTile(
    BuildContext context,
    bool isSelected, {
    required bool isPotentialMove,
    Widget? child}) {
    return Ink(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
        border: _buildBorder(
          context,
          isSelected: isSelected,
          isPotentialMove: isPotentialMove,
        ),
      ),
      child: child,
    );
  }

  Border _buildBorder(
    BuildContext context, {
    required bool isSelected,
    required bool isPotentialMove}) {
    
late final Color borderColor;
    late final double borderWidth;

    if (isSelected) {
      borderColor = Theme.of(context).colorScheme.tertiary;
      borderWidth = 6.0;
    } else if (isPotentialMove) {
      borderColor = Theme.of(context).colorScheme.tertiary;
      borderWidth = 6.0;
    } else {
      borderColor = Theme.of(context).colorScheme.primary;
      borderWidth = 3.0;
    }

    return Border.all(
      color: borderColor,
      width: borderWidth,
    );
  }

  Widget _buildPiecesOverlay(
    List<Piece> piecesOnTile,
    Player currentPlayer,
    bool debugEnabled) {
    if (piecesOnTile.isEmpty) {
      return const SizedBox.shrink();
    }

    if (tile.tileType == TileType.start || tile.tileType == TileType.finish) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Wrap(
          direction: Axis.vertical,
          spacing: 4,
          runSpacing: 4,
          children: piecesOnTile.take(7).map((piece) {
            return PieceWidget(
              player: piece.player,
              isTurnActive: piece.player == currentPlayer,
              showDebugLabel: debugEnabled,
              pieceId: piece.pieceId,
            );
          }).toList(),
        ),
      );
    }

    return Center(
      child: PieceWidget(
        player: piecesOnTile.first.player,
        isTurnActive: piecesOnTile.first.player == currentPlayer,
        showDebugLabel: debugEnabled,
        pieceId: piecesOnTile.first.pieceId,
      ),
    );
  }

  String _pieceSignature(List<Piece> piecesOnTile) {
    if (piecesOnTile.isEmpty) {
      return 'tile-${tile.tileId}-empty';
    }

    final ids = piecesOnTile.map((piece) => piece.pieceId).toList()..sort();
    return 'tile-${tile.tileId}-${ids.join('-')}';
  }

  Widget _buildDebugTag(BuildContext context) {
    final String typeCode = switch (tile.tileType) {
      TileType.basic => 'B',
      TileType.rosette => 'R',
      TileType.start => 'S',
      TileType.finish => 'F',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          '${tile.tileId}:$typeCode',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 9,
              ),
        ),
      ),
    );
  }
}