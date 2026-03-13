import 'package:flutter/material.dart';

@immutable
class BoardPosition {
  const BoardPosition({required this.x, required this.y});

  final int x;
  final int y;

  BoardPosition copyWith({int? x, int? y}) {
    return BoardPosition(
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPosition &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'BoardPosition($x, $y)';
}