import 'package:flutter/material.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/widgets/piece_widget.dart';

class TileWidget extends StatelessWidget {
  const TileWidget({
    super.key,
    required this.tile,
    this.size = 48,
    this.color,
    this.pieces = const [],
    this.currentPlayer = Player.one,
    this.hasRoll = false,
    this.onTileTap,
  });

  final Tile tile;
  final double size;
  final Color? color;
  final List<Piece> pieces;
  final Player currentPlayer;
  final bool hasRoll;
  final void Function(int tileId)? onTileTap;

  bool get _canMove =>
      hasRoll &&
      !tile.isEnd &&
      pieces.any((p) => p.owner == currentPlayer) &&
      onTileTap != null;

  List<Widget> _buildPieces(double size) {
    if (pieces.isEmpty) return [];
    final pieceSize = size * 0.36;
    final count = pieces.length;
    final spacing = pieceSize * 0.4;
    return List.generate(count, (i) {
      final piece = pieces[i];
      final row = i ~/ 3;
      final col = i % 3;
      final offsetX = (col - 1) * (pieceSize + spacing) * 0.6;
      final offsetY = (row - (count <= 3 ? 0 : 1)) * (pieceSize + spacing) * 0.6;
      return Positioned(
        left: size * 0.5 + offsetX - pieceSize * 0.5,
        top: size * 0.5 + offsetY - pieceSize * 0.5,
        child: PieceWidget(
          isPlayerOne: piece.owner == Player.one,
          size: pieceSize,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(context).colorScheme.primary.withValues(
      alpha: 0.3,
    );
    final effectiveColor = color ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final isStartOrEnd =
        tile.tileType == TileType.start || tile.tileType == TileType.end;
    final backgroundColor =
        isStartOrEnd ? Colors.transparent : effectiveColor;
    final highlighted = _canMove;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: highlighted ? () => onTileTap!(tile.id) : null,
        borderRadius: BorderRadius.circular(size * 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: highlighted ? highlightColor : backgroundColor,
            borderRadius: BorderRadius.circular(size * 0.2),
            border: highlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (tile.tileType == TileType.rosette)
                Icon(
                  Icons.local_florist,
                  size: size * 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ..._buildPieces(size),
            ],
          ),
        ),
      ),
    );
  }
}