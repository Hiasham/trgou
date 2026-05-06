import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/providers/game_controller_provider.dart';
import 'package:trgou/game/widgets/tile_widget.dart';


class BoardWidget extends ConsumerWidget {

  const BoardWidget({
    super.key
  });
  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    List<Widget> buldBoard(List<Tile> board) {
      return board.map((tile) => TileWidget(tile: tile)).toList();
    }
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
      physics: const NeverScrollableScrollPhysics(), 
      children: buldBoard(gameState.board)
    );
  }
}