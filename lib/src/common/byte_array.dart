import 'dart:convert';
import 'dart:typed_data';

import 'package:tiktoken/src/common/utils.dart';

/// Simple proxy for the Uint8List type.
///
/// Designed to be used as a key in a [HashMap] and provide consistent equality checks by
/// overriding the [hashCode] and equality[==] operator.
///
/// It exposes some methods from the Uint8List class, and adds additional helpers.
class ByteArray {
  ///Creates a [Uint8List] of the specified length (in elements), all of whose elements are initially zero.
  ByteArray(int length) : _bytes = Uint8List(length);

  ByteArray.fromList(List<int> elements)
      : _bytes = Uint8List.fromList(elements);

  ByteArray.fromString(String string)
      : _bytes = Uint8List.fromList(utf8.encode(string));

  /// Underlying [Uint8List] value
  final Uint8List _bytes;

  /// Getter for the underlying value
  Uint8List get bytes => _bytes;

  /// Decode underlying [Uint8List] value and return [String] representation
  String asString({bool allowMalformed = false}) => utf8.decode(
        _bytes,
        allowMalformed: allowMalformed,
      );

  /// Clone helper
  ByteArray clone() => ByteArray.fromList([..._bytes]);

  /// Reverse underlying value
  ByteArray get reversed => ByteArray.fromList([..._bytes.reversed]);

  @override
  bool operator ==(Object other) =>
      other is ByteArray && listEquals(_bytes, other._bytes);

  @override
  int get hashCode => bytes.fold(17, (result, el) => 31 * result + el);

  /// The number of elements in the underlying value
  int get length => _bytes.length;

  /// Checks whether the underlying collections has no elements
  bool get isEmpty => _bytes.isEmpty;

  int operator [](int index) => _bytes[index];

  void operator []=(int index, int value) => _bytes[index] = value;

  bool operator <(ByteArray other) {
    var cmp = _bytes.asMap().entries.map((entry) {
      if (entry.key >= other.length) {
        return 1;
      }

      return entry.value.compareTo(other[entry.key]);
    }).toList();

    for (var i = 0; i < cmp.length; i++) {
      if (cmp[i] < 0) {
        return true;
      } else if (cmp[i] > 0) {
        return false;
      }
    }

    return cmp.length < other.length;
  }

  @override
  String toString() {
    return _bytes.toString();
  }

  /// Returns a new ByteArray with underlying Uint8List containing the elements between [start] and [end].
  ByteArray sublist(int start, [int? end]) =>
      ByteArray.fromList(_bytes.sublist(start, end));

  /// Checks if the start of the underlying sequence equals to [other] sequence
  bool startsWith(ByteArray other) {
    if (other.isEmpty) return true;
    if (other.length > length) return false;

    for (var i = 0; i < other.bytes.length; i++) {
      if (other.bytes[i] != bytes[i]) {
        return false;
      }
    }

    return true;
  }
}

extension ListUtil on List<ByteArray> {
  /// Returns the index of the partition point according to the
  /// given predicate (the index of the first element of the second partition).
  ///
  /// The slice is assumed to be partitioned according to the given predicate.
  /// This means that all elements for which the predicate returns true are at the start of the slice
  /// and all elements for which the predicate returns false are at the end.
  int partitionPoint(bool Function(ByteArray) predicate) {
    int left = 0;
    int right = length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      if (predicate(this[mid])) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return left;
  }
}

List<ByteArray> sortListOfUint8List(List<ByteArray> list) {
  list.sort((a, b) {
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      if (a[i] < b[i]) {
        return -1;
      } else if (a[i] > b[i]) {
        return 1;
      }
    }
    return a.length - b.length;
  });

  return list;
}
