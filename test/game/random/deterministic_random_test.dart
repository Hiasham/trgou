import 'package:flutter_test/flutter_test.dart';
import 'package:trgou/game/random/deterministic_random.dart';

void main() {
  group('DeterministicRandom', () {
    test('same seed produces same sequence', () {
      final a = DeterministicRandom(seed: 42);
      final b = DeterministicRandom(seed: 42);
      for (var i = 0; i < 20; i++) {
        expect(a.nextInt(100), b.nextInt(100));
      }
    });

    test('nextInt returns values in [0, maxExclusive)', () {
      final r = DeterministicRandom(seed: 99);
      for (var i = 0; i < 50; i++) {
        final v = r.nextInt(7);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(7));
      }
    });

    test('zero seed is sanitized to 1', () {
      final r = DeterministicRandom(seed: 0);
      expect(r.seed, 1);
    });

    test('calls constructor advances stream', () {
      final base = DeterministicRandom(seed: 5);
      final advanced = DeterministicRandom(seed: 5, calls: 3);
      expect(base.calls, 0);
      expect(advanced.calls, 3);
      base.nextInt(1000);
      base.nextInt(1000);
      base.nextInt(1000);
      expect(base.nextInt(1000), advanced.nextInt(1000));
    });

    test('negative calls throws', () {
      expect(
        () => DeterministicRandom(seed: 69, calls: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('nextInt with non-positive max throws', () {
      final r = DeterministicRandom(seed: 1);
      expect(() => r.nextInt(0), throwsArgumentError);
      expect(() => r.nextInt(-1), throwsArgumentError);
    });

    test('reset restores deterministic behavior', () {
      final r = DeterministicRandom(seed: 10);
      final first = List<int>.generate(5, (_) => r.nextInt(50));
      r.reset(seed: 10);
      final second = List<int>.generate(5, (_) => r.nextInt(50));
      expect(second, first);
    });
  });
}
