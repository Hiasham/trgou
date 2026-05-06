import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/controller/game_state.dart';
import 'package:trgou/game/model/game_mode.dart';
import 'package:trgou/game/model/piece.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/rules/path_config.dart';
import 'package:trgou/game/rules/valid_moves.dart';

GameState _state(List<Piece> pieces, {Player currentPlayer = Player.playerOne}) {
  final base = GameState.initial(gameMode: GameMode.hotseat, matchSeed: 42);
  return base.copyWith(pieces: pieces, currentPlayer: currentPlayer);
}

void main() {
  group('ValidMoves.isMoveLegal', () {
    final PathConfig path = PathConfig();

    test('rejects wrong player', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerTwo, pathIndex: 0),
      ]);
      expect(
        ValidMoves.isMoveLegal(state, path, state.pieces.first, 1),
        isFalse,
      );
    });

    test('rejects non-positive roll', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 0),
      ]);
      expect(
        ValidMoves.isMoveLegal(state, path, state.pieces.first, 0),
        isFalse,
      );
    });

    test('rejects move past end of path', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 15),
      ]);
      expect(
        ValidMoves.isMoveLegal(state, path, state.pieces.first, 1),
        isFalse,
      );
    });

    test('rejects landing on friendly-occupied tile', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 5),
        const Piece(pieceId: 1, player: Player.playerOne, pathIndex: 7),
      ]);
      final mover = state.pieces.firstWhere((p) => p.pieceId == 0);
      expect(ValidMoves.isMoveLegal(state, path, mover, 2), isFalse);
    });

    test('rejects start to rosette with roll four when friendly occupies rosette', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 0),
        const Piece(pieceId: 1, player: Player.playerOne, pathIndex: 4),
      ]);
      final mover = state.pieces.firstWhere((p) => p.pieceId == 0);
      expect(ValidMoves.isMoveLegal(state, path, mover, 4), isFalse);
    });

    test('rejects capturing onto rosette occupied by enemy', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 7),
        const Piece(pieceId: 7, player: Player.playerTwo, pathIndex: 8),
      ]);
      final mover = state.pieces.firstWhere((p) => p.pieceId == 0);
      expect(ValidMoves.isMoveLegal(state, path, mover, 1), isFalse);
    });
  });

  group('ValidMoves helpers', () {
    final PathConfig path = PathConfig();

    test('hasAnyLegalMovesForRoll reflects at least one legal piece', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 0),
      ]);
      expect(ValidMoves.hasAnyLegalMovesForRoll(state, path, 1), isTrue);
    });

    test('getLegalMoveOptions is empty for non-positive roll', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 0),
      ]);
      expect(
        ValidMoves.getLegalMoveOptions(
          state,
          path,
          Player.playerOne,
          0,
        ),
        isEmpty,
      );
    });

    test('getLegalMoveOptions includes expected indices for a simple move', () {
      final state = _state([
        const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 2),
      ]);
      final options = ValidMoves.getLegalMoveOptions(
        state,
        path,
        Player.playerOne,
        1,
      );
      expect(options, hasLength(1));
      expect(options.single.pieceId, 0);
      expect(options.single.fromPathIndex, 2);
      expect(options.single.toPathIndex, 3);
    });

    test(
      'canCurrentPlayerInteractWithTile is true on rosette when roll has no legal move',
      () {
        final board = _state([
          const Piece(pieceId: 0, player: Player.playerOne, pathIndex: 8),
        ]);
        final rosetteTileId = path.getTileId(Player.playerOne, 8);
        expect(
          ValidMoves.canCurrentPlayerInteractWithTile(
            board,
            path,
            rosetteTileId,
            0,
          ),
          isTrue,
        );
      },
    );
  });
}
