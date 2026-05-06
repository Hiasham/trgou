import 'package:trgou/game/model/move_option.dart';

class MoveEvaluation {
  final MoveOption move;
  final double progressScore;
  final double safetyScore;
  final double aggressionScore;
  final double totalScore;
  final String explanation;

  const MoveEvaluation({
    required this.move,
    required this.progressScore,
    required this.safetyScore,
    required this.aggressionScore,
    required this.totalScore,
    required this.explanation,
  });
}
