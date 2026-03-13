import 'package:flutter/foundation.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/model/roll.dart';

@immutable
class GameState {
  final List<Tile> tiles;
  final List<Piece> playerOnePieces;
  final List<Piece> playerTwoPieces;
  final int playerOneScore;
  final int playerTwoScore;
  final Player currentPlayer;
  final Roll? lastRoll;
  final GameMode gameMode;

  const GameState({
    required this.tiles,
    required this.playerOnePieces,
    required this.playerTwoPieces,
    this.playerOneScore = 0,
    this.playerTwoScore = 0,
    this.gameMode = GameMode.hotseat,
    this.lastRoll,
    this.currentPlayer = Player.one,
  });

  GameState copyWith({
    List<Tile>? tiles,
    List<Piece>? playerOnePieces,
    List<Piece>? playerTwoPieces,
    int? playerOneScore,
    int? playerTwoScore,
    GameMode? gameMode,
    Roll? lastRoll,
    bool clearLastRoll = false,
    Player? currentPlayer,
  }) {
    return GameState(
      tiles: tiles ?? this.tiles,
      playerOnePieces: playerOnePieces ?? this.playerOnePieces,
      playerTwoPieces: playerTwoPieces ?? this.playerTwoPieces,
      playerOneScore: playerOneScore ?? this.playerOneScore,
      playerTwoScore: playerTwoScore ?? this.playerTwoScore,
      gameMode: gameMode ?? this.gameMode,
      lastRoll: clearLastRoll ? null : (lastRoll ?? this.lastRoll),
      currentPlayer: currentPlayer ?? this.currentPlayer,
    );
  }
}