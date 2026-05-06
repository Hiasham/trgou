import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/model/board_position.dart';

void main() {
  group('BoardPosition', () {
    test('value equality', () {
      expect(const BoardPosition(1, 2), const BoardPosition(1, 2));
      expect(const BoardPosition(1, 2), isNot(const BoardPosition(2, 1)));
    });

    test('hashCode is stable for equal positions', () {
      const a = BoardPosition(0, 7);
      const b = BoardPosition(0, 7);
      expect(a.hashCode, b.hashCode);
    });
  });
}
