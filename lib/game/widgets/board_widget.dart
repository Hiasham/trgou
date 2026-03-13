import 'package:flutter/material.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/widgets/tile_widget.dart';

class BoardWidget extends StatelessWidget {
  const BoardWidget({
    super.key,
    required this.tiles,
    this.pieces = const [],
    this.tileSize = 48,
    this.spacing = 4,
    this.currentPlayer = Player.one,
    this.hasRoll = false,
    this.onTileTap,
  });

  final List<Tile> tiles;
  final List<Piece> pieces;
  final double tileSize;
  final double spacing;
  final Player currentPlayer;
  final bool hasRoll;
  final void Function(int tileId)? onTileTap;

  int get _maxX =>
      tiles.isEmpty ? 0 : tiles.map((t) => t.position.x).reduce((a, b) => a > b ? a : b);
  int get _maxY =>
      tiles.isEmpty ? 0 : tiles.map((t) => t.position.y).reduce((a, b) => a > b ? a : b);

  Tile? _tileAt(int x, int y) {
    for (final t in tiles) {
      if (t.position.x == x && t.position.y == y) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cols = _maxX + 1;
    final rows = _maxY + 1;
    if (cols == 0 || rows == 0) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (row) {
        return Padding(
          padding: EdgeInsets.only(bottom: row < rows - 1 ? spacing : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cols, (col) {
              final tile = _tileAt(col, row);
              final tilePieces = tile != null
                  ? pieces.where((p) => p.position == tile.id).toList()
                  : <Piece>[];
              return Padding(
                padding: EdgeInsets.only(right: col < cols - 1 ? spacing : 0),
                child: tile != null
                    ? TileWidget(
                        tile: tile,
                        size: tileSize,
                        pieces: tilePieces,
                        currentPlayer: currentPlayer,
                        hasRoll: hasRoll,
                        onTileTap: onTileTap,
                      )
                    : SizedBox(width: tileSize, height: tileSize),
              );
            }),
          ),
        );
      }),
    );
  }
}
