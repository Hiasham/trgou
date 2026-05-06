class BoardPosition {
  final int x;
  final int y;

  const BoardPosition(
    this.x, 
    this.y
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}