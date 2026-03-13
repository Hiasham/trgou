import 'dart:math';
import 'package:flutter/foundation.dart';

@immutable
class Roll {
  const Roll(this.dice);

  final List<bool> dice;

  int get value => dice.where((d) => d).length;

  factory Roll.random(Random random) {
    return Roll(
      List.generate(4, (_) => random.nextBool()),
    );
  }

  @override
  String toString() => 'Roll(value: $value, dice: $dice)';
}