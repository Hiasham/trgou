import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/rules/path_config.dart';

void main() {
  group('PathConfig', () {
    final PathConfig config = PathConfig();

    test('player paths have expected length and distinct first tiles', () {
      expect(config.getPathLength(Player.playerOne), 16);
      expect(config.getPathLength(Player.playerTwo), 16);
      expect(config.getTileId(Player.playerOne, 0), 12);
      expect(config.getTileId(Player.playerTwo, 0), 14);
    });

    test('getTileId returns path element at index', () {
      for (var i = 0; i < PathConfig.playerOnePath.length; i++) {
        expect(
          config.getTileId(Player.playerOne, i),
          PathConfig.playerOnePath[i],
        );
      }
    });
  });
}
