import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trgou/game/controller/game_controller.dart';
import 'package:trgou/game/model/player.dart';
import 'package:trgou/game/random/deterministic_random.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('opening roll-off', () {
    test('completes and assigns the starter from higher roll', () async {
      final GameController controller = GameController(initialSeed: 42);
      addTearDown(controller.dispose);

      expect(controller.state.isDeterminingFirstPlayer, isTrue);
      expect(controller.state.currentPlayer, Player.playerOne);

      for (int i = 0; i < 20 && controller.state.isDeterminingFirstPlayer; i++) {
        await controller.rollDice();
      }

      expect(controller.state.isDeterminingFirstPlayer, isFalse);
      expect(controller.state.openingRollPlayerOne, isNotNull);
      expect(controller.state.openingRollPlayerTwo, isNotNull);
      expect(controller.state.openingRollPlayerOne, isNot(controller.state.openingRollPlayerTwo));
      expect(controller.state.diceRoll, isNull);

      final Player expectedStarter =
          controller.state.openingRollPlayerOne! >
              controller.state.openingRollPlayerTwo!
          ? Player.playerOne
          : Player.playerTwo;
      expect(controller.state.currentPlayer, expectedStarter);
    });

    test('tie rerolls and resets opening rolls', () async {
      final int tieSeed = _findSeedWhereFirstOpeningRollsMatch();
      final GameController controller = GameController(initialSeed: tieSeed);
      addTearDown(controller.dispose);

      await controller.rollDice();
      await controller.rollDice();

      expect(controller.state.isDeterminingFirstPlayer, isTrue);
      expect(controller.state.currentPlayer, Player.playerOne);
      expect(controller.state.openingRollPlayerOne, isNull);
      expect(controller.state.openingRollPlayerTwo, isNull);
      expect(controller.state.diceRoll, isNull);
    });

    test('ai mode auto-rolls player two during opening roll-off', () async {
      final int nonTieSeed = _findSeedWhereFirstOpeningRollsDiffer();
      final GameController controller = GameController(initialSeed: nonTieSeed);
      addTearDown(controller.dispose);
      controller.startAiMatch(seed: nonTieSeed);

      await controller.rollDice();
      expect(controller.state.openingRollPlayerOne, isNotNull);

      await _waitUntil(
        () => !controller.state.isDeterminingFirstPlayer,
        timeout: const Duration(seconds: 3),
      );

      expect(controller.state.openingRollPlayerTwo, isNotNull);
      expect(controller.state.isDeterminingFirstPlayer, isFalse);
    });
  });
}

Future<void> _waitUntil(
  bool Function() predicate, {
  required Duration timeout,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for condition after $timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

int _findSeedWhereFirstOpeningRollsMatch() {
  return _findSeed((int p1, int p2) => p1 == p2);
}

int _findSeedWhereFirstOpeningRollsDiffer() {
  return _findSeed((int p1, int p2) => p1 != p2);
}

int _findSeed(bool Function(int p1, int p2) predicate) {
  for (int seed = 1; seed <= 50000; seed++) {
    final DeterministicRandom rng = DeterministicRandom(seed: seed);
    final int p1 = _rollValue(rng);
    final int p2 = _rollValue(rng);
    if (predicate(p1, p2)) {
      return seed;
    }
  }
  throw StateError('Could not find suitable seed for opening roll-off test.');
}

int _rollValue(DeterministicRandom rng) {
  int roll = 0;
  for (int i = 0; i < 4; i++) {
    roll += rng.nextBool() ? 1 : 0;
  }
  return roll;
}
