/// Represents pair of two values of potentially different types.
class Tuple2<A, B> {
  const Tuple2(this.i1, this.i2);

  /// Item 1
  final A i1;

  /// Item 2
  final B i2;

  @override
  String toString() => "Tuple2<$A, $B>($i1, $i2)";
}
