class AIExplanation {
  final int pieceId;
  final int fromTileId;
  final int toTileId;
  final double progressScore;
  final double safetyScore;
  final double aggressionScore;
  final double totalScore;
  final String explanation;
  final String? debugDetails;

  const AIExplanation({
    required this.pieceId,
    required this.fromTileId,
    required this.toTileId,
    required this.progressScore,
    required this.safetyScore,
    required this.aggressionScore,
    required this.totalScore,
    required this.explanation,
    this.debugDetails,
  });
}
