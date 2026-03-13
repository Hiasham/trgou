import 'package:flutter/foundation.dart';
import 'board_position.dart';

@immutable
class Tile {
  const Tile({
    required this.id,
    required this.tileType,
    required this.trackType,
    required this.position,
  });

  final int id;
  final TileType tileType;
  final TrackType trackType;
  final BoardPosition position;
  bool get isRosette => tileType == TileType.rosette;
  bool get isEnd     => tileType == TileType.end;


  Tile copyWith({
    int? id,
    TileType? tileType,
    TrackType? trackType,
    BoardPosition? position,
    }) {
      return Tile(
        id: id ?? this.id,
        tileType: tileType ?? this.tileType,
        trackType: trackType ?? this.trackType,
        position: position ?? this.position,
      );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tileType == other.tileType &&
          trackType == other.trackType &&
          position == other.position;

  @override
  int get hashCode => Object.hash(id, tileType, trackType, position);

  @override
  String toString() => 'Tile(pathIndex: $id, type: $tileType, position: $position)';
}

enum TileType {
  basic,
  rosette,
  start,
  end
}

enum TrackType {
  playerOne,
  playerTwo,
  shared
}