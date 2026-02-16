import 'dart:math';

/// A deterministic random number generator service.
/// Uses a seed to ensure reproducible results for testing.
class RngService {
  final Random _random;
  final int? seed;

  /// Creates an RNG with an optional seed.
  /// If seed is provided, the random sequence will be deterministic.
  RngService({this.seed}) : _random = Random(seed);

  /// Creates an RNG with a specific seed for testing
  factory RngService.seeded(int seed) => RngService(seed: seed);

  /// Creates an RNG with no seed (truly random)
  factory RngService.unseeded() => RngService();

  /// Returns a random integer from 0 (inclusive) to [max] (exclusive)
  int nextInt(int max) => _random.nextInt(max);

  /// Returns a random double from 0.0 (inclusive) to 1.0 (exclusive)
  double nextDouble() => _random.nextDouble();

  /// Returns a random boolean
  bool nextBool() => _random.nextBool();

  /// Shuffles a list in place using Fisher-Yates algorithm
  /// Returns the same list for convenience
  List<T> shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
    return list;
  }

  /// Returns a shuffled copy of the list (doesn't modify original)
  List<T> shuffled<T>(List<T> list) {
    final copy = List<T>.from(list);
    return shuffle(copy);
  }

  /// Selects a random element from a list
  T choice<T>(List<T> list) {
    if (list.isEmpty) {
      throw ArgumentError('Cannot choose from empty list');
    }
    return list[nextInt(list.length)];
  }

  /// Selects [count] random elements from a list without replacement
  List<T> sample<T>(List<T> list, int count) {
    if (count > list.length) {
      throw ArgumentError('Sample size ($count) exceeds list length (${list.length})');
    }
    final shuffledList = shuffled(list);
    return shuffledList.take(count).toList();
  }
}
