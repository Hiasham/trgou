import 'package:flutter/material.dart';

class PieceWidget extends StatelessWidget {
  const PieceWidget({
    super.key,
    required this.isPlayerOne,
    this.size = 32,
  });

  final bool isPlayerOne;
  final double size;

  static const Color _playerOneColor = Color(0xFF2196F3); // blue
  static const Color _playerTwoColor = Color(0xFFE53935); // red

  @override
  Widget build(BuildContext context) {
    final color = isPlayerOne ? _playerOneColor : _playerTwoColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
    );
  }
}
