import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tiktoken/src/common/byte_array.dart';
import 'package:tiktoken/src/common/tuple2.dart';
import 'package:tiktoken/src/error/tiktoken_error.dart';

import 'common/utils.dart' as util;

/// BPE tokeniser
///
/// Read more on [Wikipedia](https://en.wikipedia.org/wiki/Byte_pair_encoding)
class CoreBPE {
  const CoreBPE._internal({
    required this.encoder,
    required this.specialTokensEncoder,
    required this.decoder,
    required this.specialTokensDecoder,
    required this.regex,
    required this.specialRegex,
    required this.sortedTokenBytes,
  });

  final HashMap<ByteArray, int> encoder;
  final HashMap<String, int> specialTokensEncoder;

  final HashMap<int, ByteArray> decoder;
  final HashMap<int, ByteArray> specialTokensDecoder;
  final RegExp regex;
  final RegExp specialRegex;
  final List<ByteArray> sortedTokenBytes;

  factory CoreBPE.create(
    Map<ByteArray, int> encoder,
    Map<String, int> specialTokensEncoder,
    String pattern,
  ) {
    final regex = RegExp(
      pattern,
      unicode: true,
    );
    final specialRegex = RegExp(
      specialTokensEncoder.keys.map(RegExp.escape).join("|"),
      unicode: true,
    );

    final decoder = HashMap.of(encoder.map((k, v) => MapEntry(v, k.clone())));
    assert(encoder.length == decoder.length);

    final specialTokensDecoder = HashMap.of(
      specialTokensEncoder
          .map((k, v) => MapEntry(v, ByteArray.fromList(utf8.encode(k)))),
    );

    final sortedTokenBytes = encoder.keys.toList();

    sortedTokenBytes.sort((a, b) => a.length.compareTo(b.length));

    return CoreBPE._internal(
      encoder: HashMap.from(encoder),
      specialTokensEncoder: HashMap.from(specialTokensEncoder),
      decoder: decoder,
      specialTokensDecoder: specialTokensDecoder,
      regex: regex,
      specialRegex: specialRegex,
      sortedTokenBytes:
          sortListOfUint8List(sortedTokenBytes) /*  sortedTokenBytes */,
    );
  }

  int encodeSingleToken(ByteArray bytes) {
    final token = encoder[bytes];
    if (token != null) return token;
    final specialToken = specialTokensEncoder[bytes.asString()];
    if (specialToken != null) return specialToken;

    throw TiktokenError("Error encoding single token: ${bytes.bytes}");
  }

  Uint32List encodeOrdinaryNative(String text) {
    final tokens = <int>[];

    for (var mat in regex.allMatches(text)) {
      final piece = ByteArray.fromString(mat.group(0)!);
      final token = encoder[piece];
      if (token != null) {
        tokens.add(token);
        continue;
      }
      tokens.addAll(util.bytePairEncode(piece, encoder));
    }

    return Uint32List.fromList(tokens);
  }

  Tuple2<Uint32List, int> encodeNative(
    String text,
    Set<String> allowedSpecial,
  ) {
    final tokens = <int>[];

    var start = 0;
    var lastPieceTokenLen = 0;

    while (true) {
      Match? nextSpecial;
      var startFind = start;
      while (true) {
        nextSpecial = specialRegex.firstMatch(text.substring(startFind));
        if (nextSpecial == null) {
          break;
        }

        if (allowedSpecial.contains(nextSpecial.group(0)!)) {
          break;
        }
        startFind = start + nextSpecial.end;
      }

      final end = nextSpecial == null ? text.length : start + nextSpecial.start;

      for (var mat in regex.allMatches(text.substring(start, end))) {
        var piece = ByteArray.fromList(utf8.encode(mat.group(0)!));
        if (encoder.containsKey(piece)) {
          lastPieceTokenLen = 1;
          tokens.add(encoder[piece]!);
          continue;
        }

        var encoded = util.bytePairEncode(piece, encoder);
        lastPieceTokenLen = encoded.length;
        tokens.addAll(encoded);
      }

      if (nextSpecial != null) {
        var piece = nextSpecial.group(0)!;
        var token = specialTokensEncoder[piece]!;
        tokens.add(token);
        start = start + nextSpecial.end;
        lastPieceTokenLen = 0;
      } else {
        break;
      }
    }

    return Tuple2(Uint32List.fromList(tokens), lastPieceTokenLen);
  }

  Tuple2<List<int>, Set<List<int>>> encodeUnstableNative(
    String text,
    Set<String> allowedSpecial,
  ) {
    final result = encodeNative(text, allowedSpecial);
    var tokens = [...result.i1];
    var lastPieceTokenLen = result.i2;

    if (lastPieceTokenLen == 0) return Tuple2(tokens, {});

    var increasedLastPieceTokenLen =
        _increaseLastPieceTokenLen(tokens, lastPieceTokenLen);
    tokens = [...increasedLastPieceTokenLen.i1];
    lastPieceTokenLen = increasedLastPieceTokenLen.i2;

    final unstableBytes =
        decodeNative(tokens.sublist(tokens.length - lastPieceTokenLen));

    tokens.removeRange(tokens.length - lastPieceTokenLen, tokens.length);

    final completions = HashSet<List<int>>(
      equals: util.listEquals,
      hashCode: Object.hashAll,
    );

    if (unstableBytes.isEmpty) return Tuple2(tokens, completions);

    var point = sortedTokenBytes.partitionPoint((p0) => p0 < unstableBytes);
    while (point < sortedTokenBytes.length &&
        sortedTokenBytes[point].startsWith(unstableBytes)) {
      completions.add([
        encoder[sortedTokenBytes[point]]!,
      ]);
      point++;
    }

    for (int i = 1; i < unstableBytes.length; i++) {
      final prefix = unstableBytes.sublist(0, i);
      final suffix = unstableBytes.sublist(i);

      point = sortedTokenBytes.partitionPoint((p0) => p0 < suffix);

      while (point < sortedTokenBytes.length &&
          sortedTokenBytes[point].startsWith(suffix)) {
        var possibility = [...prefix.bytes, ...sortedTokenBytes[point].bytes];
        late List<int> encoded;
        try {
          encoded = encodeOrdinaryNative(utf8.decode(possibility));
        } catch (_) {
          encoded =
              util.bytePairEncode(ByteArray.fromList(possibility), encoder);
        }
        List<int> seq = [];
        int seqLen = 0;
        for (int token in encoded) {
          seq.add(token);
          seqLen += decoder[token]!.length;
          if (seqLen >= unstableBytes.length) {
            break;
          }
        }

        completions.add(seq);
        point++;
      }
    }

    if (unstableBytes.length > 1) {
      final last = decodeLastUtf8(unstableBytes.bytes);

      if (unstableBytes.length - last.i2 > 0 && isWhitespace(last.i1)) {
        final reencoded = util.bytePairEncode(
          unstableBytes.sublist(0, unstableBytes.length - last.i2),
          encoder,
        );
        reencoded.addAll(util.bytePairEncode(
          unstableBytes.sublist(unstableBytes.length - last.i2),
          encoder,
        ));
        completions.add(reencoded);
      }
    }

    return Tuple2(tokens, completions);
  }

  ByteArray decodeNative(List<int> tokens) {
    List<int> ret = [];
    for (var token in tokens) {
      final tokenBytes = (decoder[token] ?? specialTokensDecoder[token])!.bytes;
      ret.addAll(tokenBytes);
    }

    return ByteArray.fromList(ret);
  }

  ByteArray decodeSingleTokenBytes(int token) {
    if (decoder.containsKey(token)) {
      return decoder[token]!;
    } else if (specialTokensDecoder.containsKey(token)) {
      return specialTokensDecoder[token]!;
    } else {
      throw TiktokenError(
          "Couldn't decode single token bytes for token '$token'");
    }
  }

  Tuple2<List<int>, int> _increaseLastPieceTokenLen(
    List<int> tokens,
    int lastPieceTokenLen,
  ) {
    bool tokenIsAllSpace(int token) {
      return decoder[token]?.reversed.bytes.every((b) {
            return [32, 10, 9].contains(b);
          }) ??
          false;
    }

    if (lastPieceTokenLen > 0 &&
        tokenIsAllSpace(tokens[tokens.length - lastPieceTokenLen])) {
      while (lastPieceTokenLen < tokens.length &&
          tokenIsAllSpace(tokens[tokens.length - lastPieceTokenLen - 1])) {
        lastPieceTokenLen += 1;
      }
    }
    assert(lastPieceTokenLen <= tokens.length);

    return Tuple2(tokens, lastPieceTokenLen);
  }

  List<Uint8List> tokenByteValues() {
    return sortedTokenBytes.map((e) => e.clone().bytes).toList();
  }
}

const _whitespaces = {
  ' ',
  '\n',
  '\t',
  '\r',
  '\f',
  '\v',
  '\u00a0',
  '\u1680',
  '\u2000',
  '\u200a',
  '\u2028',
  '\u2029',
  '\u202f',
  '\u205f',
  '\u3000',
  '\ufeff'
};

bool isWhitespace(String? c) => c != null && _whitespaces.contains(c);

/// UTF-8 decode a single Unicode scalar value from the end of a slice.
Tuple2<String?, int> decodeLastUtf8(List<int> slice) {
  if (slice.isEmpty) return Tuple2(null, 0);

  int i = slice.length - 1;
  while (i >= 0 && (slice[i] & 0xC0) == 0x80) {
    i--;
  }

  if (i < 0) return Tuple2(null, slice.length);

  int b = slice[i];
  int n = slice.length - i;

  if ((b & 0x80) == 0) {
    // ASCII character
    return Tuple2(String.fromCharCode(b), n);
  } else if ((b & 0xE0) == 0xC0 && n >= 2) {
    // 2-byte sequence
    int c = ((b & 0x1F) << 6) | (slice[i + 1] & 0x3F);

    return Tuple2(String.fromCharCode(c), n);
  } else if ((b & 0xF0) == 0xE0 && n >= 3) {
    // 3-byte sequence
    int c = ((b & 0x0F) << 12) |
        ((slice[i + 1] & 0x3F) << 6) |
        (slice[i + 2] & 0x3F);
    if (c >= 0x0800 && c <= 0xD7FF || c >= 0xE000 && c <= 0xFFFF) {
      return Tuple2(String.fromCharCode(c), n);
    }
  } else if ((b & 0xF8) == 0xF0 && n >= 4) {
    // 4-byte sequence
    int c = ((b & 0x07) << 18) |
        ((slice[i + 1] & 0x3F) << 12) |
        ((slice[i + 2] & 0x3F) << 6) |
        (slice[i + 3] & 0x3F);
    if (c >= 0x10000 && c <= 0x10FFFF) {
      return Tuple2(String.fromCharCode(c), n);
    }
  }

  // Invalid sequence
  return Tuple2(null, slice.length - i);
}
