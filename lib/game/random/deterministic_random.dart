class DeterministicRandom {
  static const int _mask32 = 0xFFFFFFFF;
  static const int _highBitMask = 0x80000000;
  static const int _multiplier = 1664525;
  static const int _increment = 1013904223;

  int _seed;
  int _state;
  int _calls;

  DeterministicRandom({required int seed, int calls = 0})
    : _seed = _sanitizeSeed(seed),
      _state = _sanitizeSeed(seed),
      _calls = 0 {
    if (calls < 0) {
      throw ArgumentError.value(calls, 'calls', 'must be >= 0');
    }
    for (int i = 0; i < calls; i++) {
      _nextUint32();
    }
  }

  int get seed => _seed;
  int get calls => _calls;

  void reset({required int seed, int calls = 0}) {
    if (calls < 0) {
      throw ArgumentError.value(calls, 'calls', 'must be >= 0');
    }
    _seed = _sanitizeSeed(seed);
    _state = _seed;
    _calls = 0;
    for (int i = 0; i < calls; i++) {
      _nextUint32();
    }
  }

  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive', 'must be > 0');
    }
    final int value = _nextUint32() >>> 1;
    return value % maxExclusive;
  }

  bool nextBool() {
    return (_nextUint32() & _highBitMask) != 0;
  }

  static int generateSeed() {
    final int now = DateTime.now().microsecondsSinceEpoch;
    return _sanitizeSeed(now);
  }

  static int _sanitizeSeed(int rawSeed) {
    final int normalized = rawSeed & _mask32;
    return normalized == 0 ? 1 : normalized;
  }

  int _nextUint32() {
    _state = ((_state * _multiplier) + _increment) & _mask32;
    _calls++;
    return _state;
  }
}
