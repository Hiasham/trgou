import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/ai/ai_engine.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/random/deterministic_random.dart';
import 'package:trgou/game/rules/path_config.dart';
import 'package:trgou/game/rules/valid_moves.dart';

class HeadlessAiMatchSimulator {
  HeadlessAiMatchSimulator({
    required AiConfig aiConfig,
    required int matchSeed,
    this.maxSteps = 100000,
  }) : _rng = DeterministicRandom(seed: matchSeed),
       state = GameState.initial(
         gameMode: GameMode.aiOpponent,
         matchSeed: matchSeed,
       ).copyWith(randomCallCount: 0) {
    _ai = AIEngine(config: aiConfig, random: _rng);
  }

  final PathConfig _path = PathConfig();
  final DeterministicRandom _rng;
  late final AIEngine _ai;
  final int maxSteps;

  GameState state;
  int stepCount = 0;

  HeadlessMatchResult runToCompletion() {
    while (state.winner == null && stepCount < maxSteps) {
      stepCount++;
      if (state.diceRoll == null) {
        _rollDiceSync();
      } else if (state.currentPlayer == Player.playerOne) {
        _playHumanSync();
      } else {
        _playAiSync();
      }
    }

    return HeadlessMatchResult(
      winner: state.winner,
      steps: stepCount,
      truncated: state.winner == null,
      finalRandomCalls: _rng.calls,
      matchSeed: state.matchSeed,
      aiStyleOverride: _ai.config.styleOverride,
    );
  }

  Player _next(Player p) =>
      p == Player.playerOne ? Player.playerTwo : Player.playerOne;

  List<Piece> _piecesOnTile(int tileId) {
    return state.pieces
        .where(
          (piece) =>
              _path.getTileId(piece.player, piece.pathIndex) == tileId,
        )
        .toList();
  }

  bool _isRosetteTile(int tileId) {
    for (final Tile tile in state.board) {
      if (tile.tileId == tileId) {
        return tile.tileType == TileType.rosette;
      }
    }
    return false;
  }

  Player? _winnerForPieces(List<Piece> pieces) {
    for (final Player player in Player.values) {
      final int finishIndex = _path.getPathLength(player) - 1;
      final bool allDone = pieces
          .where((Piece p) => p.player == player)
          .every((Piece p) => p.pathIndex == finishIndex);
      if (allDone) {
        return player;
      }
    }
    return null;
  }

  void _rollDiceSync() {
    int roll = 0;
    for (int i = 0; i < 4; i++) {
      roll += _rng.nextBool() ? 1 : 0;
    }
    state = state.copyWith(randomCallCount: _rng.calls);

    if (state.isDeterminingFirstPlayer) {
      _resolveOpeningRollOff(roll);
      return;
    }

    if (roll == 0) {
      state = state.copyWith(
        diceRoll: null,
        currentPlayer: _next(state.currentPlayer),
        selectedTileId: null,
      );
      return;
    }

    if (!ValidMoves.hasAnyLegalMovesForRoll(state, _path, roll)) {
      state = state.copyWith(
        diceRoll: null,
        currentPlayer: _next(state.currentPlayer),
        selectedTileId: null,
      );
      return;
    }

    state = state.copyWith(diceRoll: roll, selectedTileId: null);
  }

  void _resolveOpeningRollOff(int roll) {
    final Player roller = state.currentPlayer;
    final int? p1Roll =
        roller == Player.playerOne ? roll : state.openingRollPlayerOne;
    final int? p2Roll =
        roller == Player.playerTwo ? roll : state.openingRollPlayerTwo;

    state = state.copyWith(
      openingRollPlayerOne: p1Roll,
      openingRollPlayerTwo: p2Roll,
      selectedTileId: null,
      diceRoll: null,
      randomCallCount: _rng.calls,
    );

    if (p1Roll == null || p2Roll == null) {
      state = state.copyWith(
        currentPlayer: roller == Player.playerOne
            ? Player.playerTwo
            : Player.playerOne,
      );
      return;
    }

    if (p1Roll == p2Roll) {
      state = state.copyWith(
        currentPlayer: Player.playerOne,
        openingRollPlayerOne: null,
        openingRollPlayerTwo: null,
      );
      return;
    }

    state = state.copyWith(
      currentPlayer: p1Roll > p2Roll ? Player.playerOne : Player.playerTwo,
      isDeterminingFirstPlayer: false,
    );
  }

  void _playHumanSync() {
    final int roll = state.diceRoll!;
    final List<MoveOption> options = ValidMoves.getLegalMoveOptions(
      state,
      _path,
      Player.playerOne,
      roll,
    );
    if (options.isEmpty) {
      throw StateError('Headless sim: human has dice but no legal moves.');
    }
    options.sort((MoveOption a, MoveOption b) {
      final int byPiece = a.pieceId.compareTo(b.pieceId);
      if (byPiece != 0) {
        return byPiece;
      }
      return a.toPathIndex.compareTo(b.toPathIndex);
    });

    final MoveOption choice = options.first;
    final GameState before = state;

    final _AppliedMove applied = _applyMove(choice);
    state = applied.newState;

    if (_ai.config.styleOverride == AIStyleOverride.bayesian) {
      _ai.registerOpponentMoveAndComment(
        stateBeforeMove: before,
        opponentMove: choice,
        captureCount: applied.captureCount,
        landedOnRosette: applied.landedOnRosette,
        reachedFinish: applied.reachedFinish,
      );
    }
  }

  void _playAiSync() {
    final int roll = state.diceRoll!;
    final List<MoveOption> legal = ValidMoves.getLegalMoveOptions(
      state,
      _path,
      Player.playerTwo,
      roll,
    );
    if (legal.isEmpty) {
      throw StateError('Headless sim: AI has dice but no legal moves.');
    }

    final pick = _ai.pickBestMove(state, legal);
    if (pick == null) {
      throw StateError('Headless sim: AI pickBestMove returned null.');
    }

    final MoveOption move = pick.move;
    final _AppliedMove applied = _applyMove(move);
    state = applied.newState;

    if (_ai.config.styleOverride == AIStyleOverride.bayesian) {
      _ai.registerBayesianOutcome(
        selectedEvaluation: pick,
        captureCount: applied.captureCount,
        landedOnRosette: applied.landedOnRosette,
        wonGame: state.winner == Player.playerTwo,
      );
    }
  }

  _AppliedMove _applyMove(MoveOption executedMove) {
    final GameState before = state;
    final int? roll = before.diceRoll;
    if (roll == null || roll <= 0) {
      throw StateError('applyMove without positive dice roll.');
    }

    final Piece? piece = _pieceById(executedMove.pieceId);
    if (piece == null) {
      throw StateError('Piece ${executedMove.pieceId} not found.');
    }

    final int targetPathIndex = piece.pathIndex + roll;
    final int pathLength = _path.getPathLength(piece.player);
    final int targetTileId = _path.getTileId(piece.player, targetPathIndex);
    final bool landedOnRosette = _isRosetteTile(targetTileId);
    final bool reachedFinish = targetPathIndex == pathLength - 1;

    final int pieceIndex = before.pieces.indexWhere(
      (Piece p) => p.pieceId == piece.pieceId,
    );
    if (pieceIndex < 0) {
      throw StateError('Piece index missing for ${piece.pieceId}.');
    }

    final Set<int> capturedIds = _piecesOnTile(targetTileId)
        .where(
          (Piece targetPiece) =>
              targetPiece.player != piece.player && !landedOnRosette,
        )
        .map((Piece p) => p.pieceId)
        .toSet();

    final List<Piece> updatedPieces = List<Piece>.from(before.pieces);
    updatedPieces[pieceIndex] = piece.copyWith(pathIndex: targetPathIndex);

    for (int i = 0; i < updatedPieces.length; i++) {
      if (capturedIds.contains(updatedPieces[i].pieceId)) {
        updatedPieces[i] = updatedPieces[i].copyWith(pathIndex: 0);
      }
    }

    final Player? winner = _winnerForPieces(updatedPieces);
    final int captureCount = capturedIds.length;

    final Player movingPlayer = before.currentPlayer;
    final Player nextPlayer =
        winner ??
        (landedOnRosette ? movingPlayer : _next(movingPlayer));

    final GameState newState = before.copyWith(
      pieces: updatedPieces,
      selectedTileId: null,
      diceRoll: null,
      winner: winner,
      currentPlayer: nextPlayer,
    );

    return _AppliedMove(
      newState: newState,
      captureCount: captureCount,
      landedOnRosette: landedOnRosette,
      reachedFinish: reachedFinish,
    );
  }

  Piece? _pieceById(int pieceId) {
    for (final Piece p in state.pieces) {
      if (p.pieceId == pieceId) {
        return p;
      }
    }
    return null;
  }
}

class _AppliedMove {
  const _AppliedMove({
    required this.newState,
    required this.captureCount,
    required this.landedOnRosette,
    required this.reachedFinish,
  });

  final GameState newState;
  final int captureCount;
  final bool landedOnRosette;
  final bool reachedFinish;
}

class HeadlessMatchResult {
  const HeadlessMatchResult({
    required this.winner,
    required this.steps,
    required this.truncated,
    required this.finalRandomCalls,
    required this.matchSeed,
    required this.aiStyleOverride,
  });

  final Player? winner;
  final int steps;
  final bool truncated;
  final int finalRandomCalls;
  final int matchSeed;
  final AIStyleOverride? aiStyleOverride;

  bool get aiWon => winner == Player.playerTwo;
}

class BayesianVsFixedStrengthBenchmark {
  BayesianVsFixedStrengthBenchmark({
    this.baseConfig = const AiConfig(),
  });

  final AiConfig baseConfig;

  StrengthComparisonResult run({required List<int> seeds}) {
    final List<SingleSeedComparison> rows = <SingleSeedComparison>[];

    int fixedAiWins = 0;
    int bayesianAiWins = 0;
    int playerWinsFixed = 0;
    int playerWinsBayesian = 0;
    int incomplete = 0;

    for (final int seed in seeds) {
      final HeadlessMatchResult fixedRun = HeadlessAiMatchSimulator(
        aiConfig: baseConfig.copyWith(styleOverride: null),
        matchSeed: seed,
      ).runToCompletion();

      final HeadlessMatchResult bayesRun = HeadlessAiMatchSimulator(
        aiConfig: baseConfig.copyWith(
          styleOverride: AIStyleOverride.bayesian,
        ),
        matchSeed: seed,
      ).runToCompletion();

      if (fixedRun.truncated || bayesRun.truncated) {
        incomplete++;
      }

      if (fixedRun.winner == Player.playerTwo) {
        fixedAiWins++;
      } else if (fixedRun.winner == Player.playerOne) {
        playerWinsFixed++;
      }

      if (bayesRun.winner == Player.playerTwo) {
        bayesianAiWins++;
      } else if (bayesRun.winner == Player.playerOne) {
        playerWinsBayesian++;
      }

      rows.add(
        SingleSeedComparison(
          seed: seed,
          fixedWinner: fixedRun.winner,
          bayesianWinner: bayesRun.winner,
          fixedSteps: fixedRun.steps,
          bayesianSteps: bayesRun.steps,
          fixedTruncated: fixedRun.truncated,
          bayesianTruncated: bayesRun.truncated,
        ),
      );
    }

    return StrengthComparisonResult(
      seedsTried: seeds.length,
      fixedAiWins: fixedAiWins,
      bayesianAiWins: bayesianAiWins,
      playerWinsFixedWeights: playerWinsFixed,
      playerWinsBayesian: playerWinsBayesian,
      incompleteRuns: incomplete,
      rows: rows,
    );
  }
}

class StrengthComparisonResult {
  const StrengthComparisonResult({
    required this.seedsTried,
    required this.fixedAiWins,
    required this.bayesianAiWins,
    required this.playerWinsFixedWeights,
    required this.playerWinsBayesian,
    required this.incompleteRuns,
    required this.rows,
  });

  final int seedsTried;
  final int fixedAiWins;
  final int bayesianAiWins;
  final int playerWinsFixedWeights;
  final int playerWinsBayesian;
  final int incompleteRuns;
  final List<SingleSeedComparison> rows;

  @override
  String toString() {
    final StringBuffer b = StringBuffer()
      ..writeln(
        'Bayesian vs fixed-weight model (P2). P1 = deterministic first legal move.',
      )
      ..writeln('Seeds: $seedsTried')
      ..writeln(
        'Fixed weights — Fixed model (P2) wins: $fixedAiWins, '
        'P1 wins: $playerWinsFixedWeights',
      )
      ..writeln(
        'Bayesian — Bayesian model (P2) wins: $bayesianAiWins, '
        'P1 wins: $playerWinsBayesian',
      );
    if (incompleteRuns > 0) {
      b.writeln('Incomplete (step limit): $incompleteRuns');
    }
    b.writeln('---');
    for (final SingleSeedComparison row in rows) {
      b.writeln(row);
    }
    return b.toString();
  }
}

class SingleSeedComparison {
  const SingleSeedComparison({
    required this.seed,
    required this.fixedWinner,
    required this.bayesianWinner,
    required this.fixedSteps,
    required this.bayesianSteps,
    required this.fixedTruncated,
    required this.bayesianTruncated,
  });

  final int seed;
  final Player? fixedWinner;
  final Player? bayesianWinner;
  final int fixedSteps;
  final int bayesianSteps;
  final bool fixedTruncated;
  final bool bayesianTruncated;

  String _fixedLabel(Player? p) {
    if (p == null) {
      return '-';
    }
    return p == Player.playerTwo ? 'FixedModel' : 'P1';
  }

  String _bayesianLabel(Player? p) {
    if (p == null) {
      return '-';
    }
    return p == Player.playerTwo ? 'BayesianModel' : 'P1';
  }

  @override
  String toString() {
    return 'seed=$seed fixed=${_fixedLabel(fixedWinner)} ($fixedSteps steps'
        '${fixedTruncated ? ' TRUNC' : ''}) '
        'bayes=${_bayesianLabel(bayesianWinner)} ($bayesianSteps steps'
        '${bayesianTruncated ? ' TRUNC' : ''})';
  }
}
