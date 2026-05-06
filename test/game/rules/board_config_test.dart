import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/model/board_position.dart';
import 'package:trgou/game/model/tile.dart';
import 'package:trgou/game/rules/board_config.dart';

void main() {
  group('BoardConfig', () {
    final BoardConfig config = BoardConfig();

    test('createBoard produces 3x8 tiles with unique ids', () {
      final board = config.createBoard();
      expect(board.length, 24);
      final ids = board.map((t) => t.tileId).toList()..sort();
      expect(ids, List<int>.generate(24, (i) => i));
    });

    test('getTileType classifies starts, finishes, rosettes', () {
      expect(config.getTileType(0, 4), TileType.start);
      expect(config.getTileType(2, 4), TileType.start);
      expect(config.getTileType(0, 5), TileType.finish);
      expect(config.getTileType(2, 5), TileType.finish);
      expect(config.getTileType(1, 3), TileType.rosette);
      expect(config.getTileType(1, 4), TileType.basic);
    });

    test('getTrackType maps columns', () {
      expect(config.getTrackType(0), TrackType.playerOne);
      expect(config.getTrackType(1), TrackType.shared);
      expect(config.getTrackType(2), TrackType.playerTwo);
      expect(() => config.getTrackType(3), throwsException);
    });

    test('static start and finish positions are consistent', () {
      expect(BoardConfig.starts, contains(const BoardPosition(0, 4)));
      expect(BoardConfig.finishes, contains(const BoardPosition(0, 5)));
    });
  });
}
