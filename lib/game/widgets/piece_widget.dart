import 'package:flutter/material.dart';
import 'package:trgou/game/model/player.dart';

class PieceWidget extends StatelessWidget {
  final Player player;
  final bool isTurnActive;
  final bool showDebugLabel;
  final int? pieceId;

  const PieceWidget({
    required this.player,
    required this.isTurnActive,
    this.showDebugLabel = false,
    this.pieceId,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    final Color pieceColor = player == Player.playerOne
        ? const Color.fromARGB(255, 126, 148, 134)
        : const Color(0xFFE6A57E);

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pieceColor,
        boxShadow: isTurnActive
            ? [
                BoxShadow(
                  color: pieceColor.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 2.6,
                ),
              ]
            : null,
      ),
      child: showDebugLabel && pieceId != null
          ? Center(
              child: Text(
                '$pieceId',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }
}