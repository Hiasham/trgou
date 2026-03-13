import 'package:flutter/material.dart';
import 'player.dart';

@immutable
class Piece {
  final Player owner;
  final int position;

  const Piece({required this.owner, required this.position});

  Piece copyWith({int? position}) {
    return Piece(owner: owner, position: position ?? this.position);
  }
}