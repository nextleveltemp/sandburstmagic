/// Deterministic, persistable pseudo-random number generator.
///
/// The game needs randomness that can be *reproduced*: the Daily Puzzle must
/// be the same for everyone on the same date, and a level must deal the same
/// pieces every time it is played. `dart:math`'s [Random] cannot expose
/// its internal state, so we use mulberry32: a tiny, well-known 32-bit
/// generator whose whole state is a single integer.
///
/// All arithmetic is kept within 32 bits explicitly so the sequence is the same
/// on every platform. The algorithm is mirrored by `tool/reference_model`
/// (core.py) and verified against it in `test/core/reference_test.dart`.
class SeededRng {
  SeededRng(int seed) : _state = seed & mask32;

  static const int mask32 = 0xFFFFFFFF;

  int _state;

  /// The current state.
  int get state => _state;

  /// Returns the next unsigned 32-bit value.
  int nextU32() {
    _state = (_state + 0x6D2B79F5) & mask32;
    var t = _state;
    t = imul32(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + imul32(t ^ (t >> 7), t | 61)) & mask32)) & mask32;
    return (t ^ (t >> 14)) & mask32;
  }

  /// Returns an integer in `[0, n)`. `n` must be in `1..2^20`.
  int nextInt(int n) {
    assert(n > 0 && n <= (1 << 20), 'nextInt bound out of range: $n');
    return (nextU32() * n) >> 32;
  }

  /// 32-bit integer multiplication (like JavaScript's Math.imul), computed in
  /// 16-bit halves so no intermediate value exceeds 2^53.
  static int imul32(int a, int b) {
    a &= mask32;
    b &= mask32;
    final ah = (a >> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return (al * bl + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) & mask32;
  }

  /// FNV-1a 32-bit hash of a string's UTF-16 code units. Used to turn a date
  /// such as `2026-10-19` into a daily seed.
  static int hashString(String input) {
    var h = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      h ^= unit & 0xFFFF;
      h = imul32(h, 0x01000193);
    }
    return h & mask32;
  }
}
