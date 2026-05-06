import 'package:trgou/game/ai/ai_explanation.dart';
import 'package:trgou/game/rules/board_config.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';

class GameState {
  static const Object _unset = Object();

  final List<Tile> board;
  final List<Piece> pieces;
  final int? selectedTileId;
  final Player currentPlayer;
  final int? diceRoll;
  final int rollShakeCounter;
  final Player? winner;
  final GameMode gameMode;
  final AIExplanation? latestAiExplanation;
  final int matchSeed;
  final int randomCallCount;
  final bool isDeterminingFirstPlayer;
  final int? openingRollPlayerOne;
  final int? openingRollPlayerTwo;

  GameState({
    required this.board,
    required this.pieces,
    required this.selectedTileId,
    required this.currentPlayer,
    required this.diceRoll,
    required this.rollShakeCounter,
    required this.winner,
    required this.gameMode,
    required this.latestAiExplanation,
    required this.matchSeed,
    required this.randomCallCount,
    required this.isDeterminingFirstPlayer,
    required this.openingRollPlayerOne,
    required this.openingRollPlayerTwo,
  });

  factory GameState.initial({
    required GameMode gameMode,
    required int matchSeed,
  }) {
    final boardConfig = BoardConfig();

    return GameState(
      board: boardConfig.createBoard(),
      pieces: _generatePieces(),
      currentPlayer: Player.playerOne,
      selectedTileId: null,
      diceRoll: null,
      rollShakeCounter: 0,
      winner: null,
      gameMode: gameMode,
      latestAiExplanation: null,
      matchSeed: matchSeed,
      randomCallCount: 0,
      isDeterminingFirstPlayer: true,
      openingRollPlayerOne: null,
      openingRollPlayerTwo: null,
    );
  }

  GameState copyWith({
    List<Tile>? board,
    List<Piece>? pieces,
    Player? currentPlayer,
    Object? selectedTileId = _unset,
    Object? diceRoll = _unset,
    Object? rollShakeCounter = _unset,
    Object? winner = _unset,
    GameMode? gameMode,
    Object? latestAiExplanation = _unset,
    int? matchSeed,
    int? randomCallCount,
    bool? isDeterminingFirstPlayer,
    Object? openingRollPlayerOne = _unset,
    Object? openingRollPlayerTwo = _unset,
  }) {
    return GameState(
      board: board ?? this.board,
      pieces: pieces ?? this.pieces,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      selectedTileId: selectedTileId == _unset
          ? this.selectedTileId
          : selectedTileId as int?,
      diceRoll: diceRoll == _unset ? this.diceRoll : diceRoll as int?,
      rollShakeCounter: rollShakeCounter == _unset
          ? this.rollShakeCounter
          : rollShakeCounter as int,
      winner: winner == _unset ? this.winner : winner as Player?,
      gameMode: gameMode ?? this.gameMode,
      latestAiExplanation: latestAiExplanation == _unset
          ? this.latestAiExplanation
          : latestAiExplanation as AIExplanation?,
      matchSeed: matchSeed ?? this.matchSeed,
      randomCallCount: randomCallCount ?? this.randomCallCount,
      isDeterminingFirstPlayer:
          isDeterminingFirstPlayer ?? this.isDeterminingFirstPlayer,
      openingRollPlayerOne: openingRollPlayerOne == _unset
          ? this.openingRollPlayerOne
          : openingRollPlayerOne as int?,
      openingRollPlayerTwo: openingRollPlayerTwo == _unset
          ? this.openingRollPlayerTwo
          : openingRollPlayerTwo as int?,
    );
  }

  static List<Piece> _generatePieces() {
    final pieces = <Piece>[];

    for (int i = 0; i < 7; i++) {
      pieces.add(Piece(pieceId: i, player: Player.playerOne, pathIndex: 0));
    }

    for (int i = 7; i < 14; i++) {
      pieces.add(Piece(pieceId: i, player: Player.playerTwo, pathIndex: 0));
    }

    return pieces;
  }
}
