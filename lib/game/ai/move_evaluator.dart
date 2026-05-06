import 'package:trgou/game/ai/ai_explanation_builder.dart';
import 'package:trgou/game/ai/move_evaluation.dart';
import 'package:trgou/game/ai/value_weights.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/rules/path_config.dart';

class MoveEvaluator {
  final PathConfig _pathConfig;
  final AiExplanationBuilder _explanationBuilder;

  MoveEvaluator({
    PathConfig? pathConfig,
    AiExplanationBuilder? explanationBuilder,
  })  : _pathConfig = pathConfig ?? PathConfig(),
        _explanationBuilder = explanationBuilder ?? const AiExplanationBuilder();

  MoveEvaluation evaluateMove(
    GameState state,
    MoveOption move,
    ValueWeights weights) {
    final Piece? piece = _getPieceById(state, move.pieceId);
    if (piece == null) {
      return MoveEvaluation(
        move: move,
        progressScore: 0,
        safetyScore: 0,
        aggressionScore: 0,
        totalScore: 0,
        explanation: 'Invalid move: piece ${move.pieceId} not found.',
      );
    }

    final Player player = piece.player;

    final double progressScore = _scoreProgress(player, move);
    final double safetyScore = _scoreSafety(state, player, move);
    final double aggressionScore = _scoreAggression(state, player, move);

    final double totalScore =
        (progressScore * weights.progress) +
        (safetyScore * weights.safety) +
        (aggressionScore * weights.aggression);

    final MoveEvaluation evaluation = MoveEvaluation(
      move: move,
      progressScore: progressScore,
      safetyScore: safetyScore,
      aggressionScore: aggressionScore,
      totalScore: totalScore,
      explanation: '',
    );

    return MoveEvaluation(
      move: evaluation.move,
      progressScore: evaluation.progressScore,
      safetyScore: evaluation.safetyScore,
      aggressionScore: evaluation.aggressionScore,
      totalScore: evaluation.totalScore,
      explanation: _explanationBuilder.buildForEvaluation(evaluation),
    );
  }

  double _scoreProgress(Player player, MoveOption move) {
    final int pathLength = _pathConfig.getPathLength(player);
    if (pathLength <= 1) {
      return 0;
    }

    final double fromNormalized = move.fromPathIndex / (pathLength - 1);
    final double toNormalized = move.toPathIndex / (pathLength - 1);

    return toNormalized + ((toNormalized - fromNormalized) * 0.25);
  }

  double _scoreSafety(GameState state, Player player, MoveOption move) {
    final Tile? destinationTile = move.destinationTile ?? _getTileById(state, move.toTileId);
    if (destinationTile == null) {
      return 0;
    }

    double score = 0;

    if (destinationTile.tileType == TileType.rosette) {
      score += 1.0;
    }
    if (destinationTile.tileType == TileType.finish) {
      score += 1.2;
    }
    if (destinationTile.trackType == TrackType.shared) {
      score -= 0.2;
    }

    if (destinationTile.trackType == TrackType.shared &&
        destinationTile.tileType != TileType.rosette &&
        destinationTile.tileType != TileType.finish) {
      final int enemyThreats = _countEnemyThreatsToTile(state, player, move.toTileId);
      score -= enemyThreats * 0.25;
    }

    return score;
  }

  double _scoreAggression(GameState state, Player player, MoveOption move) {
    final Tile? destinationTile = move.destinationTile ?? _getTileById(state, move.toTileId);
    if (destinationTile == null) {
      return 0;
    }

    if (destinationTile.tileType == TileType.rosette) {
      return 0;
    }

    final List<Piece> capturableEnemies = state.pieces.where((piece) {
      if (piece.player == player) {
        return false;
      }
      final int enemyTileId = _pathConfig.getTileId(piece.player, piece.pathIndex);
      return enemyTileId == move.toTileId;
    }).toList();

    if (capturableEnemies.isEmpty) {
      return 0;
    }

    double score = capturableEnemies.length.toDouble();

    if (destinationTile.trackType == TrackType.shared) {
      score += 0.25;
    }

    double bestFinishPressure = 0;
    for (final Piece enemyPiece in capturableEnemies) {
      final int pathLength = _pathConfig.getPathLength(enemyPiece.player);
      if (pathLength <= 1) {
        continue;
      }
      final double normalizedProgress = enemyPiece.pathIndex / (pathLength - 1);
      if (normalizedProgress > bestFinishPressure) {
        bestFinishPressure = normalizedProgress;
      }
    }
    score += bestFinishPressure * 0.35;

    final int enemyThreats = _countEnemyThreatsToTile(state, player, move.toTileId);
    score -= enemyThreats * 0.2;

    return score;
  }

  int _countEnemyThreatsToTile(GameState state, Player player, int tileId) {
    int threatCount = 0;

    for (final piece in state.pieces) {
      if (piece.player == player) {
        continue;
      }

      for (int roll = 1; roll <= 4; roll++) {
        final int targetPathIndex = piece.pathIndex + roll;
        final int pathLength = _pathConfig.getPathLength(piece.player);
        if (targetPathIndex < 0 || targetPathIndex >= pathLength) {
          continue;
        }

        final int targetTileId = _pathConfig.getTileId(piece.player, targetPathIndex);
        if (targetTileId == tileId) {
          threatCount++;
          break;
        }
      }
    }

    return threatCount;
  }

  Piece? _getPieceById(GameState state, int pieceId) {
    for (final piece in state.pieces) {
      if (piece.pieceId == pieceId) {
        return piece;
      }
    }
    return null;
  }

  Tile? _getTileById(GameState state, int tileId) {
    for (final tile in state.board) {
      if (tile.tileId == tileId) {
        return tile;
      }
    }
    return null;
  }
}
