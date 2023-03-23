import 'dart:math';
import 'dart:typed_data';

import 'package:tiktoken/src/common/byte_array.dart';
import 'package:tiktoken/src/common/tuple2.dart';
import 'package:tiktoken/src/core_bpe.dart';
import 'package:tiktoken/src/error/tiktoken_error.dart';

import 'common/special_tokens_set.dart';

/// Tiktoken encoder/decoder.
///
/// It exposes APIs for processing text using tokens.
/// Can be extended t o support new encodings.
///
/// Example:
/// ```dart
/// // 1. Get the base encoder
/// final baseEnc = getEncoding("cl100kBase");
///
/// // 2. Create custom encoder by extending baseEnc
/// final enc = Tiktoken(
///   name: "cl100k_im",
///   patStr: cl100kBase.patStr,
///   mergeableRanks: cl100kBase.mergeableRanks,
///   specialTokens: {
///     ...cl100kBase.specialTokens,
///     // 3. We provide additional tokens
///     "<|im_start|>": 100264,
///     "<|im_end|>": 100265,
///   },
/// );
/// ```
class Tiktoken {
  Tiktoken({
    required this.name,
    required this.patStr,
    required this.mergeableRanks,
    required this.specialTokens,
    this.explicitNVocab,
  }) {
    maxTokenValue = max(
      mergeableRanks.values.reduce(max),
      specialTokens.values.reduce(max),
    );

    if (explicitNVocab != null) {
      assert(mergeableRanks.length + specialTokens.length == explicitNVocab);
      assert(maxTokenValue == explicitNVocab! - 1);
    }

    specialTokensSet = specialTokens.keys.toSet();

    _coreBPE = CoreBPE.create(mergeableRanks, specialTokens, patStr);
  }

  /// A set of special tokens keys
  late final Set<String> specialTokensSet;

  /// The name of the encoding.
  ///
  /// It should be clear from the name of the encoding what behaviour to expect,
  /// in particular, encodings with different special tokens
  /// should have different names.
  final String name;

  /// A regex pattern string that is used to split the input text.
  final String patStr;

  /// A dictionary mapping mergeable token bytes to their ranks.
  /// The ranks must correspond to merge priority.
  final Map<ByteArray, int> mergeableRanks;

  /// A dictionary mapping special token strings to their token values.
  final Map<String, int> specialTokens;

  /// The number of tokens in the vocabulary.
  /// If provided, it is checked that the number of mergeable tokens
  /// and special tokens is equal to this number.
  final int? explicitNVocab;

  /// BPE tokeniser
  late final CoreBPE _coreBPE;

  late final int maxTokenValue;

  /// Encodes a string into tokens.
  ///
  /// Special tokens are artificial tokens used to unlock capabilities from a model,
  /// such as fill-in-the-middle. So we want to be careful about accidentally encoding special
  /// tokens, since they can be used to trick a model into doing something we don't want it to do.
  ///
  /// Hence, by default, encode will raise an error if it encounters text that corresponds
  /// to a special token. This can be controlled on a per-token level using the `allowedSpecial`
  /// and `disallowedSpecial` parameters. In particular:
  /// - Setting `disallowedSpecial` to SpecialTokensSet.empty() will prevent this function from raising errors and
  ///   cause all text corresponding to special tokens to be encoded as natural text.
  /// - Setting `allowedSpecial` to SpecialTokensSet.all() will cause this function to treat all text
  ///   corresponding to special tokens to be encoded as special tokens.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2"); // Get instance of encoder
  /// enc.encode("hello world"); // [31373, 995]
  /// enc.encode("<|endoftext|>", allowedSpecial: SpecialTokensSet.custom({"<|endoftext|>"})); // [50256]
  /// enc.encode("<|endoftext|>", allowedSpecial: SpecialTokensSet.all()); // [50256]
  /// enc.encode("<|endoftext|>") // Throws
  /// enc.encode("<|endoftext|>", disallowedSpecial: SpecialTokensSet.empty()); // [27, 91, 437, 1659, 5239, 91, 29]
  /// ```
  Uint32List encode(
    String text, {
    SpecialTokensSet allowedSpecial = const SpecialTokensSet.empty(),
    SpecialTokensSet disallowedSpecial = const SpecialTokensSet.all(),
  }) {
    final allowedSpecialSet =
        allowedSpecial.isAll ? specialTokensSet : allowedSpecial.set;

    final disallowedSpecialSet = disallowedSpecial.isAll
        ? specialTokensSet.difference(allowedSpecialSet)
        : disallowedSpecial.set;

    _verifyDisallowed(text, disallowedSpecialSet);

    return _coreBPE.encodeNative(text, allowedSpecialSet).i1;
  }

  /// Encodes a string into tokens, ignoring special tokens.
  ///
  /// This is equivalent to `encode(text, disallowedSpecial = SpecialTokensSet.empty())` (but slightly faster).
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.encode_ordinary("hello world"); // [31373, 995]
  /// ```
  Uint32List encodeOrdinary(String text) {
    return _coreBPE.encodeOrdinaryNative(text);
  }

  /// Encodes a string into stable tokens and possible completion sequences.
  ///
  /// Note that the stable tokens will only represent a substring of `text`.
  ///
  /// See `encode` for more details on `allowedSpecial` and `disallowedSpecial`.
  ///
  /// This API should itself be considered unstable.
  ///
  /// ```dart
  /// final enc = getEncoding("gpt2"); // Get instance of encoder
  /// enc.encodeWithUnstable("hello fanta") // Tuple2([31373], [(277, 4910), (5113, 265), ..., (8842,)])
  ///
  /// final text = "hello";
  /// final result = enc.encodeWithUnstable(text)
  /// final stableTokens = result.i1, completions = result.i2;
  /// assert(text.encode().startswith(enc.decode_bytes(stable_tokens)))
  /// assert all(enc.decode_bytes(stable_tokens + seq).startswith(text.encode()) for seq in completions)
  /// ```
  Tuple2<List<int>, Set<List<int>>> encodeWithUnstable(
    String text, {
    SpecialTokensSet allowedSpecial = const SpecialTokensSet.empty(),
    SpecialTokensSet disallowedSpecial = const SpecialTokensSet.all(),
  }) {
    final allowedSpecialSet =
        allowedSpecial.isAll ? specialTokensSet : allowedSpecial.set;

    final disallowedSpecialSet = disallowedSpecial.isAll
        ? specialTokensSet.difference(allowedSpecialSet)
        : disallowedSpecial.set;

    _verifyDisallowed(text, disallowedSpecialSet);

    return _coreBPE.encodeUnstableNative(text, allowedSpecialSet);
  }

  /// Encodes text corresponding to a single token to its token value.
  ///
  /// NOTE: this will encode all special tokens.
  ///
  /// Throws `TiktokenError` if the token is not in the vocabulary.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.encodeSingleToken("hello") // 31373
  /// ```
  int encodeSingleToken(List<int> bytes) {
    return _coreBPE.encodeSingleToken(ByteArray.fromList(bytes));
  }

  /// Decodes a list of tokens into bytes.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.decodeBytes([31373, 995]); // [104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]
  /// ```
  Uint8List decodeBytes(List<int> tokens) {
    return _coreBPE.decodeNative(tokens).bytes;
  }

  /// Decodes a list of tokens into a string.
  ///
  /// WARNING: the default behaviour of this function is lossy, since decoded bytes are not
  /// guaranteed to be valid UTF-8. You can control this behaviour using the `allowMalformed` parameter,
  /// for instance, setting `allowMalformed = false`.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.decode([31373, 995]); // 'hello world'
  /// ```
  String decode(List<int> tokens, {bool allowMalformed = true}) {
    return _coreBPE.decodeNative(tokens).asString(
          allowMalformed: allowMalformed,
        );
  }

  /// Decodes a token into bytes.
  ///
  /// NOTE: this will decode all special tokens.
  ///
  /// Throws `TiktokenError` if the token is not in the vocabulary.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.decodeSingleTokenBytes(31373); // [104, 101, 108, 108, 111]
  /// ```
  Uint8List decodeSingleTokenBytes(int token) {
    return _coreBPE.decodeSingleTokenBytes(token).bytes;
  }

  /// Decodes a list of tokens into a list of bytes.
  ///
  /// Useful for visualising tokenisation.
  ///
  /// Example:
  /// ```dart
  /// final enc = getEncoding("gpt2");
  /// enc.decodeTokenBytes([31373, 995]); // [[104, 101, 108, 108, 111], [32, 119, 111, 114, 108, 100]]
  /// ```
  List<Uint8List> decodeTokenBytes(List<int> tokens) {
    return tokens.map((token) => decodeSingleTokenBytes(token)).toList();
  }

  int? get eotToken => specialTokens["<|endoftext|>"];

  /// Returns `sortedTokenBytes` from underlying [CoreBPE] tokenizer.
  List<Uint8List> tokenByteValues() => _coreBPE.tokenByteValues();

  void _verifyDisallowed(String text, Set<String> disallowedSpecialSet) {
    if (disallowedSpecialSet.isNotEmpty) {
      var disallowedRegex = _specialTokenRegex(disallowedSpecialSet);
      var match = disallowedRegex.firstMatch(text);
      if (match != null) {
        throw TiktokenError(
            "Encountered text corresponding to disallowed special token '${match.group(0)}'.\n"
            "If you want this text to be encoded as a special token, "
            "pass it to `allowedSpecial`, e.g. `allowedSpecial = SpecialTokensSet.custom({'${match.group(0)}', ...})`.\n"
            "If you want this text to be encoded as normal text, disable the check for this token "
            "by passing `disallowedSpecial = (enc.specialTokensSet.difference({'${match.group(0)}'}))`.\n"
            "To disable this check for all special tokens, pass `disallowedSpecial = SpecialTokensSet.empty()`.\n");
      }
    }
  }
}

RegExp _specialTokenRegex(Set<String> tokens) {
  final inner = tokens.map(RegExp.escape).join("|");

  return RegExp(inner, unicode: true);
}
