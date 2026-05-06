import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:trgou/game/ai/ai_explanation.dart';
import 'package:trgou/game/ai/ai_config.dart';
import 'package:trgou/game/ai/ai_engine.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/logging/explanation_event_logger.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/persistence/game_state_persistence.dart';
import 'package:trgou/game/random/deterministic_random.dart';
import 'package:trgou/game/rules/path_config.dart';
import 'package:trgou/game/rules/valid_moves.dart';

class GameController extends StateNotifier<GameState> {
  static const int _diceCount = 4;
  static const Duration _aiExplanationClearWaitStep = Duration(
    milliseconds: 100,
  );
  static const Duration _aiExplanationClearWaitTimeout = Duration(seconds: 10);

  final PathConfig _pathConfig = PathConfig();
  final DeterministicRandom _rng;
  final AIEngine _aiEngine;
  final GameStatePersistence _persistence = const GameStatePersistence();
  final ExplanationEventLogger _explanationLogger = const ExplanationEventLogger();
  bool _isAiThinking = false;

  GameController({AiConfig? aiConfig, int? initialSeed})
    : this._(
        aiConfig: aiConfig,
        rng: DeterministicRandom(
          seed: initialSeed ?? DeterministicRandom.generateSeed(),
        ),
      );

  GameController._({required DeterministicRandom rng, AiConfig? aiConfig})
    : _rng = rng,
      _aiEngine = AIEngine(config: aiConfig, random: rng),
      super(GameState.initial(gameMode: GameMode.hotseat, matchSeed: rng.seed));

  void _log(String message) {
    debugPrint('[GameController] $message');
  }

  void reset({GameMode mode = GameMode.hotseat, int? seed}) {
    final int nextSeed = seed ?? DeterministicRandom.generateSeed();
    _log('reset() called; mode=$mode, seed=$nextSeed.');
    _rng.reset(seed: nextSeed, calls: 0);
    if (mode != GameMode.aiOpponent) {
      _aiEngine.config = _aiEngine.config.copyWith(styleOverride: null);
    }
    _aiEngine.resetBayesianLearning();
    _setState(
      GameState.initial(
        gameMode: mode,
        matchSeed: _rng.seed,
      ).copyWith(randomCallCount: _rng.calls),
    );
    _maybeRunAiTurn();
  }

  void startAiMatch({AIStyleOverride? aiStyleOverride, int? seed}) {
    _aiEngine.config = _aiEngine.config.copyWith(
      styleOverride: aiStyleOverride,
    );
    reset(mode: GameMode.aiOpponent, seed: seed);
  }

  void clearLatestAiExplanation() {
    if (state.latestAiExplanation == null) {
      return;
    }

    _log('Clearing AI explanation from state.');
    _setState(state.copyWith(latestAiExplanation: null));
  }

  Future<bool> loadPersistedState() async {
    final PersistedGameSnapshot? snapshot = await _persistence.load();
    if (snapshot == null) {
      _log('No persisted game state found.');
      return false;
    }

    _aiEngine.config = _aiEngine.config.copyWith(
      styleOverride: snapshot.aiStyleOverride,
    );
    _rng.reset(
      seed: snapshot.state.matchSeed,
      calls: snapshot.state.randomCallCount,
    );
    _setState(
      snapshot.state.copyWith(
        matchSeed: _rng.seed,
        randomCallCount: _rng.calls,
      ),
      persist: false,
    );
    _log('Persisted game state restored (mode=${state.gameMode}).');
    _maybeRunAiTurn();
    return true;
  }

  bool get isAiTurn =>
      state.gameMode == GameMode.aiOpponent &&
      state.currentPlayer == Player.playerTwo &&
      state.winner == null;

  BayesianLearningDiagnostics? get bayesianLearningDiagnostics =>
      _aiEngine.bayesianLearningDiagnostics;

  void onTileTapped(Tile tile) {
    _log(
      'onTileTapped(tileId=${tile.tileId}, currentPlayer=${state.currentPlayer}, diceRoll=${state.diceRoll})',
    );
    if (state.isDeterminingFirstPlayer) {
      _log('Tap ignored during opening roll-off.');
      _setState(state.copyWith(rollShakeCounter: state.rollShakeCounter + 1));
      return;
    }

    if (isAiTurn) {
      _log('Tap ignored because AI controls current player.');
      return;
    }

    if (state.winner != null) {
      _log('Tap ignored because winner is already set: ${state.winner}.');
      return;
    }

    if (state.diceRoll == null) {
      _log('Tap before rolling; triggering roll button shake.');
      _setState(state.copyWith(rollShakeCounter: state.rollShakeCounter + 1));
      return;
    }

    if (!hasAnyLegalMovesForCurrentPlayer()) {
      _log('Tap ignored; no legal moves available for current player.');
      return;
    }

    final int? potentialMoveTileId = getPotentialMoveTileId();
    if (potentialMoveTileId != null && tile.tileId == potentialMoveTileId) {
      _log(
        'Tapped potential move tile $potentialMoveTileId; moving selected piece.',
      );
      moveSelectedPiece();
      return;
    }

    if (!canCurrentPlayerInteractWithTile(tile.tileId)) {
      _log(
        'Tap ignored; tile ${tile.tileId} is not interactable for this turn.',
      );
      return;
    }

    final isAlreadySelected = state.selectedTileId == tile.tileId;
    _log(
      isAlreadySelected
          ? 'Deselecting tile ${tile.tileId}.'
          : 'Selecting tile ${tile.tileId}.',
    );
    _setState(
      state.copyWith(selectedTileId: isAlreadySelected ? null : tile.tileId),
    );
  }

  Future<void> rollDice() async {
    _log('rollDice() called; currentPlayer=${state.currentPlayer}.');
    if (isAiTurn && !_isAiThinking) {
      _log('Manual roll ignored because AI controls current player.');
      return;
    }

    if (state.winner != null) {
      _log('Roll ignored because winner is already set: ${state.winner}.');
      return;
    }

    if (state.diceRoll != null) {
      _log('Roll ignored because diceRoll already exists: ${state.diceRoll}.');
      return;
    }

    int roll = 0;
    for (int i = 0; i < _diceCount; i++) {
      roll += _rng.nextBool() ? 1 : 0;
    }
    _log('Rolled value: $roll (seed=${state.matchSeed}, calls=${_rng.calls}).');

    if (state.isDeterminingFirstPlayer) {
      _handleOpeningRollOff(roll);
      return;
    }

    if (roll == 0) {
      final bool shouldExplainPlayerZeroRoll =
          state.gameMode == GameMode.aiOpponent &&
          state.currentPlayer == Player.playerOne &&
          _aiEngine.config.styleOverride == AIStyleOverride.bayesian;
      _log('Rolled 0; showing value for 2 seconds before passing turn.');
      _setState(
        state.copyWith(
          selectedTileId: null,
          diceRoll: 0,
          randomCallCount: _rng.calls,
          latestAiExplanation: shouldExplainPlayerZeroRoll
              ? const AIExplanation(
                  pieceId: -1,
                  fromTileId: -1,
                  toTileId: -1,
                  progressScore: 0,
                  safetyScore: 0,
                  aggressionScore: 0,
                  totalScore: 0,
                  explanation: 'Player rolled 0, no progress this turn.',
                )
              : state.latestAiExplanation,
        ),
      );
      if (shouldExplainPlayerZeroRoll) {
        _logStructuredExplanation(
          eventType: 'player_zero_roll',
          explanation: 'Player rolled 0, no progress this turn.',
          progressScore: 0,
          safetyScore: 0,
          aggressionScore: 0,
          totalScore: 0,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));

      if (state.diceRoll != 0) {
        _log(
          'State changed during zero-roll delay; skipping forced turn pass.',
        );
        return;
      }

      final nextPlayer = _getNextPlayer(state.currentPlayer);
      _log('Zero-roll timeout complete; passing turn to $nextPlayer.');
      _setState(
        state.copyWith(
          selectedTileId: null,
          diceRoll: null,
          currentPlayer: nextPlayer,
          randomCallCount: _rng.calls,
        ),
      );
      _maybeRunAiTurn();
      return;
    }

    if (!_hasAnyLegalMovesForRoll(roll)) {
      final nextPlayer = _getNextPlayer(state.currentPlayer);
      _log('No legal moves for roll $roll; passing turn to $nextPlayer.');
      _setState(
        state.copyWith(
          selectedTileId: null,
          diceRoll: null,
          currentPlayer: nextPlayer,
          randomCallCount: _rng.calls,
        ),
      );
      _maybeRunAiTurn();
      return;
    }

    _log('Roll accepted; waiting for tile selection.');
    _setState(state.copyWith(diceRoll: roll, randomCallCount: _rng.calls));
    _maybeRunAiTurn();
  }

  int _getTileIdForPiece(Piece piece) {
    return _pathConfig.getTileId(piece.player, piece.pathIndex);
  }

  List<Piece> getPiecesOnTile(int tileId) {
    return state.pieces
        .where((piece) => _getTileIdForPiece(piece) == tileId)
        .toList();
  }

  bool isMoveLegal(Piece piece, int roll) {
    return ValidMoves.isMoveLegal(state, _pathConfig, piece, roll);
  }

  bool canCurrentPlayerInteractWithTile(int tileId) {
    final int? roll = state.diceRoll;
    if (roll == null) {
      return false;
    }

    return ValidMoves.canCurrentPlayerInteractWithTile(
      state,
      _pathConfig,
      tileId,
      roll,
    );
  }

  bool hasAnyLegalMovesForCurrentPlayer() {
    final int? roll = state.diceRoll;
    if (roll == null) {
      return false;
    }

    final hasMoves = _hasAnyLegalMovesForRoll(roll);
    _log('hasAnyLegalMovesForCurrentPlayer(roll=$roll) => $hasMoves');
    return hasMoves;
  }

  bool _hasAnyLegalMovesForRoll(int roll) {
    return ValidMoves.hasAnyLegalMovesForRoll(state, _pathConfig, roll);
  }

  List<MoveOption> getLegalMoveOptionsForAiPlayer(int roll) {
    return ValidMoves.getLegalMoveOptions(
      state,
      _pathConfig,
      Player.playerTwo,
      roll,
    );
  }

  int? getSelectedPieceId() {
    final int? selectedTileId = state.selectedTileId;
    if (selectedTileId == null) {
      return null;
    }

    final piecesOnTile = getPiecesOnTile(selectedTileId);
    for (final piece in piecesOnTile) {
      if (piece.player == state.currentPlayer) {
        return piece.pieceId;
      }
    }

    return null;
  }

  int? getPotentialMoveTileId() {
    final int? roll = state.diceRoll;
    final int? selectedPieceId = getSelectedPieceId();
    if (roll == null || roll <= 0 || selectedPieceId == null) {
      _log(
        'No potential move tile (roll=$roll, selectedPieceId=$selectedPieceId).',
      );
      return null;
    }

    final Piece? selectedPiece = _getPieceById(selectedPieceId);
    if (selectedPiece == null) {
      _log('Selected piece lookup failed for id=$selectedPieceId.');
      return null;
    }

    if (!isMoveLegal(selectedPiece, roll)) {
      _log(
        'Selected piece ${selectedPiece.pieceId} has no legal target for roll $roll.',
      );
      return null;
    }

    final int targetPathIndex = selectedPiece.pathIndex + roll;
    final int targetTileId = _pathConfig.getTileId(
      selectedPiece.player,
      targetPathIndex,
    );
    _log(
      'Potential move tile for piece ${selectedPiece.pieceId}: $targetTileId.',
    );
    return targetTileId;
  }

  bool moveSelectedPiece() {
    _log('moveSelectedPiece() called.');
    final GameState stateBeforeMove = state;
    final int? selectedPieceId = getSelectedPieceId();
    final int? roll = state.diceRoll;

    if (selectedPieceId == null || roll == null) {
      _log('[ERROR] selectedPieceId=$selectedPieceId, roll=$roll.');
      return false;
    }

    final Piece? piece = _getPieceById(selectedPieceId);
    if (piece == null) {
      _log('[ERROR] Couldn\'t find piece with id=$selectedPieceId.');
      return false;
    }

    if (!isMoveLegal(piece, roll)) {
      _log('[ERROR] ${piece.pieceId} is not legal for roll $roll.');
      return false;
    }

    final int targetPathIndex = piece.pathIndex + roll;
    final int pathLength = _pathConfig.getPathLength(piece.player);
    if (targetPathIndex < 0 || targetPathIndex >= pathLength) {
      _log('[ERROR] targetPathIndex=$targetPathIndex is out of bounds.');
      return false;
    }
    final int targetTileId = _pathConfig.getTileId(
      piece.player,
      targetPathIndex,
    );
    final bool landedOnRosette = _isRosetteTile(targetTileId);
    final bool reachedFinish = targetPathIndex == (pathLength - 1);
    final MoveOption executedMove = MoveOption(
      pieceId: piece.pieceId,
      fromPathIndex: piece.pathIndex,
      toPathIndex: targetPathIndex,
      fromTileId: _getTileIdForPiece(piece),
      toTileId: targetTileId,
      destinationTile: _getTileById(targetTileId),
    );
    _log(
      'Moving piece ${piece.pieceId} to tile $targetTileId (rosette=$landedOnRosette).',
    );

    final int pieceIndex = state.pieces.indexWhere(
      (existingPiece) => existingPiece.pieceId == piece.pieceId,
    );
    if (pieceIndex == -1) {
      _log('[ERROR] No index found for piece: ${piece.pieceId}.');
      return false;
    }

    final capturedPieceIds = getPiecesOnTile(targetTileId)
        .where(
          (targetPiece) =>
              targetPiece.player != piece.player && !landedOnRosette,
        )
        .map((targetPiece) => targetPiece.pieceId)
        .toSet();

    final List<Piece> updatedPieces = List<Piece>.from(state.pieces);
    updatedPieces[pieceIndex] = piece.copyWith(pathIndex: targetPathIndex);

    for (int i = 0; i < updatedPieces.length; i++) {
      final current = updatedPieces[i];
      if (capturedPieceIds.contains(current.pieceId)) {
        updatedPieces[i] = current.copyWith(pathIndex: 0);
      }
    }

    final Player? winner = _getWinnerForPieces(updatedPieces);
    final int captureCount = capturedPieceIds.length;
    if (capturedPieceIds.isNotEmpty) {
      _log('Captured piece ids: ${capturedPieceIds.toList()}.');
    }
    if (winner != null) {
      _log('Winnr: $winner.');
    }

    final Player movingPlayer = state.currentPlayer;
    final Player nextPlayer =
        winner ??
        (landedOnRosette ? movingPlayer : _getNextPlayer(movingPlayer));

    AIExplanation? postPlayerMoveCommentary;
    if (stateBeforeMove.gameMode == GameMode.aiOpponent &&
        movingPlayer == Player.playerOne &&
        _aiEngine.config.styleOverride == AIStyleOverride.bayesian &&
        winner == null &&
        nextPlayer == Player.playerTwo) {
      final commentary = _aiEngine.registerOpponentMoveAndComment(
        stateBeforeMove: stateBeforeMove,
        opponentMove: executedMove,
        captureCount: captureCount,
        landedOnRosette: landedOnRosette,
        reachedFinish: reachedFinish,
      );
      if (commentary != null) {
        _log('Adaptive debug: ${commentary.debugDetails}');
        _logStructuredExplanation(
          eventType: 'adaptive_response_to_player_move',
          explanation: commentary.explanation,
          debugDetails: commentary.debugDetails,
          move: executedMove,
          captureCount: captureCount,
          landedOnRosette: landedOnRosette,
          reachedFinish: reachedFinish,
          progressScore: commentary.observedEvaluation.progressScore,
          safetyScore: commentary.observedEvaluation.safetyScore,
          aggressionScore: commentary.observedEvaluation.aggressionScore,
          totalScore: commentary.observedEvaluation.totalScore,
          contextState: stateBeforeMove,
        );
        postPlayerMoveCommentary = AIExplanation(
          pieceId: executedMove.pieceId,
          fromTileId: executedMove.fromTileId,
          toTileId: executedMove.toTileId,
          progressScore: commentary.observedEvaluation.progressScore,
          safetyScore: commentary.observedEvaluation.safetyScore,
          aggressionScore: commentary.observedEvaluation.aggressionScore,
          totalScore: commentary.observedEvaluation.totalScore,
          explanation: commentary.explanation,
          debugDetails: commentary.debugDetails,
        );
      }
    }

    if (postPlayerMoveCommentary != null) {
      _setState(
        state.copyWith(
          pieces: updatedPieces,
          selectedTileId: null,
          diceRoll: null,
          winner: winner,
          currentPlayer: nextPlayer,
          latestAiExplanation: postPlayerMoveCommentary,
        ),
      );
    } else {
      _setState(
        state.copyWith(
          pieces: updatedPieces,
          selectedTileId: null,
          diceRoll: null,
          winner: winner,
          currentPlayer: nextPlayer,
        ),
      );
    }
    _maybeRunAiTurn();
    _log(
      'Move resolved. Next player: ${state.currentPlayer}, winner: ${state.winner}, diceRoll reset.',
    );
    return true;
  }

  Player? _getWinnerForPieces(List<Piece> pieces) {
    for (final player in Player.values) {
      final int finishPathIndex = _pathConfig.getPathLength(player) - 1;
      final bool allFinished = pieces
          .where((piece) => piece.player == player)
          .every((piece) => piece.pathIndex == finishPathIndex);
      if (allFinished) {
        _log('All pieces finished for $player.');
        return player;
      }
    }
    return null;
  }

  bool _isRosetteTile(int tileId) {
    for (final tile in state.board) {
      if (tile.tileId == tileId) {
        return tile.tileType == TileType.rosette;
      }
    }
    return false;
  }

  Piece? _getPieceById(int pieceId) {
    for (final piece in state.pieces) {
      if (piece.pieceId == pieceId) {
        return piece;
      }
    }
    return null;
  }

  Tile? _getTileById(int tileId) {
    for (final tile in state.board) {
      if (tile.tileId == tileId) {
        return tile;
      }
    }
    return null;
  }

  Player _getNextPlayer(Player currentPlayer) {
    final Player nextPlayer = switch (currentPlayer) {
      Player.playerOne => Player.playerTwo,
      Player.playerTwo => Player.playerOne,
    };
    _log('Trun swapped: $currentPlayer -> $nextPlayer.');
    return nextPlayer;
  }

  void _handleOpeningRollOff(int roll) {
    final Player roller = state.currentPlayer;
    final int? p1Roll = roller == Player.playerOne ? roll : state.openingRollPlayerOne;
    final int? p2Roll = roller == Player.playerTwo ? roll : state.openingRollPlayerTwo;

    _log('Opening roll-off: $roller rolled $roll.');
    _setState(
      state.copyWith(
        openingRollPlayerOne: p1Roll,
        openingRollPlayerTwo: p2Roll,
        randomCallCount: _rng.calls,
      ),
    );

    if (p1Roll == null || p2Roll == null) {
      final Player nextRoller = roller == Player.playerOne
          ? Player.playerTwo
          : Player.playerOne;
      _setState(
        state.copyWith(
          currentPlayer: nextRoller,
          selectedTileId: null,
          diceRoll: null,
          randomCallCount: _rng.calls,
        ),
      );
      _maybeRunAiTurn();
      return;
    }

    if (p1Roll == p2Roll) {
      _log('Opening roll-off tied at $p1Roll. Re-rolling both players.');
      _setState(
        state.copyWith(
          currentPlayer: Player.playerOne,
          openingRollPlayerOne: null,
          openingRollPlayerTwo: null,
          selectedTileId: null,
          diceRoll: null,
          randomCallCount: _rng.calls,
        ),
      );
      _maybeRunAiTurn();
      return;
    }

    final Player starter = p1Roll > p2Roll ? Player.playerOne : Player.playerTwo;
    _log('Opening roll-off winner: $starter (P1=$p1Roll, P2=$p2Roll).');
    _setState(
      state.copyWith(
        currentPlayer: starter,
        isDeterminingFirstPlayer: false,
        selectedTileId: null,
        diceRoll: null,
        randomCallCount: _rng.calls,
      ),
    );
    _maybeRunAiTurn();
  }

  List<MoveOption> _getLegalMoveOptionsForCurrentRoll(int roll) {
    return ValidMoves.getLegalMoveOptions(
      state,
      _pathConfig,
      state.currentPlayer,
      roll,
    );
  }

  void _maybeRunAiTurn() {
    if (!isAiTurn || _isAiThinking) {
      return;
    }

    Future<void>(() async {
      await _performAiTurn();
    });
  }

  Future<void> _performAiTurn() async {
    if (!isAiTurn || _isAiThinking) {
      return;
    }

    _isAiThinking = true;
    _log('AI turn started for Player 2.');
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!isAiTurn) {
        return;
      }

      if (state.diceRoll == null) {
        await _waitForAiExplanationToClear();
        if (!isAiTurn) {
          return;
        }
        await rollDice();
      }

      if (!isAiTurn || state.diceRoll == null) {
        return;
      }

      final int roll = state.diceRoll!;
      final legalMoveOptions = _getLegalMoveOptionsForCurrentRoll(roll);
      if (legalMoveOptions.isEmpty) {
        _log('AI found no legal move options after rolling $roll.');
        return;
      }

      final AiDecisionTrace? aiTrace = _aiEngine.pickBestMoveTrace(
        state,
        legalMoveOptions,
      );
      if (aiTrace == null) {
        _log('AI engine could not score a move for roll $roll.');
        return;
      }
      final aiChoice = aiTrace.selectedEvaluation;

      final MoveOption selectedMove = aiChoice.move;
      final bool landedOnRosette = _isRosetteTile(selectedMove.toTileId);
      final int captureCount = landedOnRosette
          ? 0
          : _countOpponentPiecesOnTile(
              tileId: selectedMove.toTileId,
              perspectivePlayer: Player.playerTwo,
            );
      final int selectedTileId = selectedMove.fromTileId;
      final List<MoveScoreTrace> candidateMoveScores = aiTrace
          .candidateEvaluations
          .map(
            (evaluation) => MoveScoreTrace(
              pieceId: evaluation.move.pieceId,
              fromTileId: evaluation.move.fromTileId,
              toTileId: evaluation.move.toTileId,
              progressScore: evaluation.progressScore,
              safetyScore: evaluation.safetyScore,
              aggressionScore: evaluation.aggressionScore,
              totalScore: evaluation.totalScore,
              selected: evaluation.move.pieceId == selectedMove.pieceId &&
                  evaluation.move.fromTileId == selectedMove.fromTileId &&
                  evaluation.move.toTileId == selectedMove.toTileId,
            ),
          )
          .toList();
      _setState(
        state.copyWith(
          selectedTileId: selectedTileId,
          randomCallCount: _rng.calls,
          latestAiExplanation: AIExplanation(
            pieceId: selectedMove.pieceId,
            fromTileId: selectedMove.fromTileId,
            toTileId: selectedMove.toTileId,
            progressScore: aiChoice.progressScore,
            safetyScore: aiChoice.safetyScore,
            aggressionScore: aiChoice.aggressionScore,
            totalScore: aiChoice.totalScore,
            explanation: aiChoice.explanation,
          ),
        ),
      );
      _logStructuredExplanation(
        eventType: 'ai_selected_move',
        explanation: aiChoice.explanation,
        debugDetails: aiChoice.explanation,
        move: selectedMove,
        captureCount: captureCount,
        landedOnRosette: landedOnRosette,
        reachedFinish: selectedMove.toPathIndex ==
            (_pathConfig.getPathLength(Player.playerTwo) - 1),
        progressScore: aiChoice.progressScore,
        safetyScore: aiChoice.safetyScore,
        aggressionScore: aiChoice.aggressionScore,
        totalScore: aiChoice.totalScore,
        weightProgress: aiTrace.activeWeights.progress,
        weightSafety: aiTrace.activeWeights.safety,
        weightAggression: aiTrace.activeWeights.aggression,
        inferredPlayerProgress: aiTrace.inferredPlayerTendencies?.progress,
        inferredPlayerSafety: aiTrace.inferredPlayerTendencies?.safety,
        inferredPlayerAggression: aiTrace.inferredPlayerTendencies?.aggression,
        inferredPlayerConfidence: aiTrace.inferredPlayerTendencies?.confidence,
        responseEfficacy: aiTrace.responseEfficacy,
        candidateMoveScores: candidateMoveScores,
      );
      _log(
        'AI selected piece ${selectedMove.pieceId} on tile '
        '$selectedTileId. ${aiChoice.explanation}',
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bool moved = moveSelectedPiece();
      if (moved) {
        _aiEngine.registerBayesianOutcome(
          selectedEvaluation: aiChoice,
          captureCount: captureCount,
          landedOnRosette: landedOnRosette,
          wonGame: state.winner == Player.playerTwo,
        );
      }
    } finally {
      _isAiThinking = false;
      _maybeRunAiTurn();
    }
  }

  Future<void> _waitForAiExplanationToClear() async {
    if (state.latestAiExplanation == null) {
      return;
    }

    _log('AI waiting for explanation bubble to clear before rolling.');
    final Stopwatch stopwatch = Stopwatch()..start();
    while (isAiTurn && state.latestAiExplanation != null) {
      if (stopwatch.elapsed >= _aiExplanationClearWaitTimeout) {
        _log('Timed out waiting for explanation to clear; continuing AI turn.');
        return;
      }
      await Future<void>.delayed(_aiExplanationClearWaitStep);
    }
  }

  int _countOpponentPiecesOnTile({
    required int tileId,
    required Player perspectivePlayer,
  }) {
    int count = 0;
    for (final piece in getPiecesOnTile(tileId)) {
      if (piece.player != perspectivePlayer) {
        count++;
      }
    }
    return count;
  }

  void _setState(GameState newState, {bool persist = true}) {
    state = newState;
    if (!persist) {
      return;
    }

    _persistLatestState();
  }

  void _persistLatestState() {
    unawaited(
      _persistence.save(
        state: state,
        aiStyleOverride: _aiEngine.config.styleOverride,
      ),
    );
  }

  void _logStructuredExplanation({
    required String eventType,
    required String explanation,
    String? debugDetails,
    MoveOption? move,
    int? captureCount,
    bool? landedOnRosette,
    bool? reachedFinish,
    double? progressScore,
    double? safetyScore,
    double? aggressionScore,
    double? totalScore,
    double? weightProgress,
    double? weightSafety,
    double? weightAggression,
    double? inferredPlayerProgress,
    double? inferredPlayerSafety,
    double? inferredPlayerAggression,
    double? inferredPlayerConfidence,
    double? responseEfficacy,
    List<MoveScoreTrace>? candidateMoveScores,
    GameState? contextState,
  }) {
    final GameState sourceState = contextState ?? state;
    final DateTime now = DateTime.now().toUtc();
    final String entryId =
        '${sourceState.matchSeed}-${sourceState.randomCallCount}-${now.microsecondsSinceEpoch}';

    unawaited(
      _explanationLogger.append(
        ExplanationLogEntry(
          id: entryId,
          timestampIso: now.toIso8601String(),
          eventType: eventType,
          matchSeed: sourceState.matchSeed,
          randomCallCount: sourceState.randomCallCount,
          gameMode: sourceState.gameMode.name,
          currentPlayer: sourceState.currentPlayer.name,
          winner: sourceState.winner?.name,
          aiStyleOverride: _aiEngine.config.styleOverride?.name,
          pieceId: move?.pieceId,
          fromTileId: move?.fromTileId,
          toTileId: move?.toTileId,
          fromPathIndex: move?.fromPathIndex,
          toPathIndex: move?.toPathIndex,
          captureCount: captureCount,
          landedOnRosette: landedOnRosette,
          reachedFinish: reachedFinish,
          progressScore: progressScore,
          safetyScore: safetyScore,
          aggressionScore: aggressionScore,
          totalScore: totalScore,
          weightProgress: weightProgress,
          weightSafety: weightSafety,
          weightAggression: weightAggression,
          inferredPlayerProgress: inferredPlayerProgress,
          inferredPlayerSafety: inferredPlayerSafety,
          inferredPlayerAggression: inferredPlayerAggression,
          inferredPlayerConfidence: inferredPlayerConfidence,
          responseEfficacy: responseEfficacy,
          candidateMoveScores: candidateMoveScores ?? const <MoveScoreTrace>[],
          playerFacingExplanation: explanation,
          debugDetails: debugDetails,
        ),
      ),
    );
  }
}
