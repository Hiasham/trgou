enum Player {
  one,
  two;

  int get id => this == Player.one ? 1 : 2;
}
