import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/move_option.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/rules/path_config.dart';

class ValidMoves {
  static bool isMoveLegal(
    GameState state,
    PathConfig pathConfig,
    Piece piece,
    int roll) {

    if (piece.player != state.currentPlayer || roll <= 0) {
      return false;
    }

    final int targetPathIndex = piece.pathIndex + roll;

    final int pathLength = pathConfig.getPathLength(piece.player);

    if (targetPathIndex < 0 || targetPathIndex >= pathLength) {
      return false;
    }

    final int targetTileId = pathConfig.getTileId(piece.player, targetPathIndex);

    final List<Piece> piecesOnTargetTile = _getPiecesOnTile(state, pathConfig, targetTileId);

    final bool isFinishTile = _isTileType(state, targetTileId, TileType.finish);

    final bool isRosetteTile = _isTileType(state, targetTileId, TileType.rosette);

    final bool hasFriendlyPieceOnTarget = piecesOnTargetTile.any(
      (targetPiece) => targetPiece.player == piece.player,
    );
    if (hasFriendlyPieceOnTarget && !isFinishTile) {
      return false;
    }

    final bool hasEnemyPieceOnTarget = piecesOnTargetTile.any(
      (targetPiece) => targetPiece.player != piece.player,
    );
    if (isRosetteTile && hasEnemyPieceOnTarget) {
      return false;
    }

    return true;
  }

  static bool hasAnyLegalMovesForRoll(
    GameState state,
    PathConfig pathConfig,
    int roll) {
    return state.pieces.any(
      (piece) => piece.player == state.currentPlayer && isMoveLegal(state, pathConfig, piece, roll),
    );
  }

  static List<MoveOption> getLegalMoveOptions(
    GameState state,
    PathConfig pathConfig,
    Player player,
    int roll,
  ) {
    if (roll <= 0) {
      return const <MoveOption>[];
    }

    final List<MoveOption> legalMoves = <MoveOption>[];
    for (final piece in state.pieces) {
      if (piece.player != player) {
        continue;
      }

      if (!isMoveLegal(state, pathConfig, piece, roll)) {
        continue;
      }

      final int fromPathIndex = piece.pathIndex;
      final int toPathIndex = piece.pathIndex + roll;
      final int fromTileId = pathConfig.getTileId(piece.player, fromPathIndex);
      final int toTileId = pathConfig.getTileId(piece.player, toPathIndex);

      legalMoves.add(
        MoveOption(
          pieceId: piece.pieceId,
          fromPathIndex: fromPathIndex,
          toPathIndex: toPathIndex,
          fromTileId: fromTileId,
          toTileId: toTileId,
          destinationTile: _getTileById(state, toTileId),
        ),
      );
    }

    return legalMoves;
  }

  static bool canCurrentPlayerInteractWithTile(
    GameState state,
    PathConfig pathConfig,
    int tileId,
    int roll) {
    final List<Piece> piecesOnTile = _getPiecesOnTile(state, pathConfig, tileId);
    final List<Piece> currentPlayerPieces = piecesOnTile
        .where((piece) => piece.player == state.currentPlayer)
        .toList();
    if (currentPlayerPieces.isEmpty) {
      return false;
    }

    final bool hasLegalMoveFromTile = currentPlayerPieces.any(
      (piece) => piece.player == state.currentPlayer && isMoveLegal(state, pathConfig, piece, roll),
    );
    if (hasLegalMoveFromTile) {
      return true;
    }

    final bool isRosetteTile = _isTileType(state, tileId, TileType.rosette);
    if (isRosetteTile) {
      return true;
    }

    return false;
  }

  static List<Piece> _getPiecesOnTile(
    GameState state,
    PathConfig pathConfig,
    int tileId) {
    return state.pieces.where((piece) {
      final int pieceTileId = pathConfig.getTileId(piece.player, piece.pathIndex);
      return pieceTileId == tileId;
    }).toList();
  }

  static bool _isTileType(GameState state, int tileId, TileType tileType) {
    for (final tile in state.board) {
      if (tile.tileId == tileId) {
        return tile.tileType == tileType;
      }
    }
    return false;
  }

  static Tile? _getTileById(GameState state, int tileId) {
    for (final tile in state.board) {
      if (tile.tileId == tileId) {
        return tile;
      }
    }
    return null;
  }
}
