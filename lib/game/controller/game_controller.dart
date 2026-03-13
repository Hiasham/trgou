import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/model/roll.dart';
import 'package:trgou/game/persistence/game_state_persistence.dart';
import 'package:trgou/game/rules/board_config.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/ai/ai_strategy.dart';

final class GameController extends StateNotifier<GameState> {
  GameController()
      : super(GameState(
          tiles: List<Tile>.from(BoardConfig.tiles),
          gameMode: GameMode.hotseat,
          playerOnePieces: List.generate(
            7,
            (_) => const Piece(owner: Player.one, position: BoardConfig.playerOneStartTileId),
          ),
          playerTwoPieces: List.generate(
            7,
            (_) => const Piece(owner: Player.two, position: BoardConfig.playerTwoStartTileId),
          ),
        ));

  static final _random = Random();

  void _persist() => unawaited(saveGameState(state));

  void loadState(GameState newState) {
    state = newState;
    _persist();
  }

  void roll() {
    final newRoll = Roll.random(_random);
    state = state.copyWith(lastRoll: newRoll);
    if (!_hasValidMove()) {
      state = state.copyWith(
        clearLastRoll: true,
        currentPlayer: state.currentPlayer == Player.one ? Player.two : Player.one,
      );
    }
    _persist();
  }

  bool _hasValidMove() {
    final roll = state.lastRoll;
    if (roll == null) return false;
    final player = state.currentPlayer;
    final pieces = player == Player.one ? state.playerOnePieces : state.playerTwoPieces;
    final path = BoardConfig.pathFor(player);
    final opponentPieces = player == Player.one ? state.playerTwoPieces : state.playerOnePieces;
    for (final piece in pieces) {
      final fromTileId = piece.position;
      if (fromTileId < 0) continue;
      final pathIndex = path.indexOf(fromTileId);
      if (pathIndex == -1) continue;
      if (state.tiles.any((t) => t.id == fromTileId && t.isEnd)) continue;
      final newIndex = pathIndex + roll.value;
      if (newIndex >= path.length) continue;
      final newTileId = path[newIndex];
      final destinationIsEnd = state.tiles.any((t) => t.id == newTileId && t.isEnd);
      final destinationIsStart = state.tiles.any((t) => t.id == newTileId && t.tileType == TileType.start);
      final destinationIsRosette = state.tiles.any((t) => t.id == newTileId && t.isRosette);
      final myPieceOnDestination = pieces.any((p) => p.position == newTileId);
      final opponentPieceOnDestination = opponentPieces.any((p) => p.position == newTileId);
      if (newTileId != fromTileId && !destinationIsEnd && !destinationIsStart && myPieceOnDestination) continue;
      if (destinationIsRosette && opponentPieceOnDestination) continue;
      return true;
    }
    return false;
  }

  /// Moves one of the current player's pieces from [fromTileId] by [lastRoll] spaces.
  /// No-op if no roll, no piece on tile, or destination off path. Roll of 0 still requires selecting a piece, then turn passes.
  void movePiece(int fromTileId) {
    final roll = state.lastRoll;
    if (roll == null) return;

    final player = state.currentPlayer;
    final pieces = player == Player.one ? state.playerOnePieces : state.playerTwoPieces;
    final path = BoardConfig.pathFor(player);
    final pathIndex = path.indexOf(fromTileId);
    if (pathIndex == -1) return;

    final idx = pieces.indexWhere((p) => p.position == fromTileId);
    if (idx == -1) return;

    final newIndex = pathIndex + roll.value;
    if (newIndex >= path.length) return;

    final newTileId = path[newIndex];
    final destinationIsEnd = state.tiles.any((t) => t.id == newTileId && t.isEnd);
    final destinationIsStart = state.tiles.any((t) => t.id == newTileId && t.tileType == TileType.start);
    final destinationIsRosette = state.tiles.any((t) => t.id == newTileId && t.isRosette);
    final myPieceOnDestination = pieces.any((p) => p.position == newTileId);
    final opponentPieceOnDestination = (player == Player.one ? state.playerTwoPieces : state.playerOnePieces)
        .any((p) => p.position == newTileId);
    if (newTileId != fromTileId && !destinationIsEnd && !destinationIsStart && myPieceOnDestination) return;
    if (destinationIsRosette && opponentPieceOnDestination) return;

    final newPieces = List<Piece>.from(pieces);
    newPieces[idx] = pieces[idx].copyWith(position: newTileId);

    final opponent = player == Player.one ? Player.two : Player.one;
    final opponentPieces = player == Player.one ? state.playerTwoPieces : state.playerOnePieces;
    final oppIdx = opponentPieces.indexWhere((p) => p.position == newTileId);
    List<Piece> newOpponentPieces = opponentPieces;
    if (oppIdx >= 0) {
      newOpponentPieces = List<Piece>.from(opponentPieces);
      newOpponentPieces[oppIdx] = opponentPieces[oppIdx].copyWith(
        position: BoardConfig.startTileIdFor(opponent),
      );
    }

    state = state.copyWith(
      playerOnePieces: player == Player.one ? newPieces : newOpponentPieces,
      playerTwoPieces: player == Player.two ? newPieces : newOpponentPieces,
      clearLastRoll: true,
      currentPlayer: destinationIsRosette ? player : opponent,
    );

    _persist();

    final endTileId = path.last;
    if (newPieces.every((p) => p.position == endTileId)) {
      resetBoard();
    }
  }

  void scorePoint(int player) {
    // 
  }

  void resetBoard() {
    state = state.copyWith(
      tiles: List<Tile>.from(BoardConfig.tiles),
      currentPlayer: Player.one,
      clearLastRoll: true,
      playerOnePieces: List.generate(
        7,
        (_) => const Piece(owner: Player.one, position: BoardConfig.playerOneStartTileId),
      ),
      playerTwoPieces: List.generate(
        7,
        (_) => const Piece(owner: Player.two, position: BoardConfig.playerTwoStartTileId),
      ),
    );
    _persist();
  }

  void setGameMode(GameMode mode) {
    state = state.copyWith(gameMode: mode);
    _persist();
  }

  /// One bot turn: roll, then if there is a valid move, choose with [strategy] and move.
  void performBotTurn(AiStrategy strategy) {
    roll();
    if (!_hasValidMove()) return;
    final fromTileId = strategy(state);
    if (fromTileId != null) movePiece(fromTileId);
  }

  /// Bot move only (no roll). Call after showing the bot's roll.
  void performBotMove(AiStrategy strategy) {
    if (!_hasValidMove()) return;
    final fromTileId = strategy(state);
    if (fromTileId != null) movePiece(fromTileId);
  }

  /// True when it is the bot's turn and they have no roll yet (need to roll/move).
  bool get isBotTurnWithNoRoll =>
      state.gameMode == GameMode.bot &&
      state.currentPlayer == Player.two &&
      state.lastRoll == null;
}
