import 'dart:collection';

import 'package:tiktoken/src/common/byte_array.dart';

/// Max value of 32-bit signed integer
// ignore: constant_identifier_names
const _MAX = 2147483647;

typedef BytePairCallback<T> = T Function(int start, int end);

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  if (identical(a, b)) return true;

  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }

  return true;
}

List<int> bytePairEncode(ByteArray piece, HashMap<ByteArray, int> ranks) {
  if (piece.length == 1) return [ranks[piece]!];

  return _bytePairMerge(
    piece,
    ranks,
    (start, end) => ranks[piece.sublist(start, end)]!,
  );
}

List<T> _bytePairMerge<T>(
  ByteArray piece,
  HashMap<ByteArray, int> ranks,
  BytePairCallback<T> cb,
) {
  final parts = List.generate(piece.length + 1, (i) => [i, _MAX]);

  int? getRank(int startIdx, [int skip = 0]) {
    if (startIdx + skip + 2 < parts.length) {
      return ranks[
          piece.sublist(parts[startIdx][0], parts[startIdx + skip + 2][0])];
    } else {
      return null;
    }
  }

  for (var i = 0; i < parts.length - 2; i++) {
    final rank = getRank(i);
    if (rank != null) {
      assert(rank != _MAX);
      parts[i][1] = rank;
    }
  }

  while (parts.length > 1) {
    var minRank = [_MAX, 0];
    for (var i = 0; i < parts.length - 1; i++) {
      if (parts[i][1] < minRank[0]) {
        minRank = [parts[i][1], i];
      }
    }

    if (minRank[0] != _MAX) {
      final i = minRank[1];

      parts[i][1] = getRank(i, 1) ?? _MAX;
      if (i > 0) {
        parts[i - 1][1] = getRank(i - 1, 1) ?? _MAX;
      }

      parts.removeAt(i + 1);
    } else {
      break;
    }
  }

  return List.generate(
    parts.length - 1,
    (i) => cb(parts[i][0], parts[i + 1][0]),
  );
}
