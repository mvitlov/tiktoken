/// tiktoken is a [BPE](https://en.wikipedia.org/wiki/Byte_pair_encoding) tokeniser for use with OpenAI's models.
/// It exposes APIs used to process text using tokens.

library tiktoken;

import 'package:tiktoken/src/core_bpe_constructor.dart';
import 'package:tiktoken/src/error/tiktoken_error.dart';

import 'src/tiktoken.dart';

export 'src/common/special_tokens_set.dart';
export 'src/mappings.dart';
export 'src/tiktoken.dart';

// ignore: non_constant_identifier_names
final _ENCODINGS = <String, Tiktoken>{};

// ignore: non_constant_identifier_names
Map<String, CoreBPEConstructor Function()>? _ENCODING_CONSTRUCTORS;

void _getCtor() {
  if (_ENCODING_CONSTRUCTORS != null) return;

  _ENCODING_CONSTRUCTORS = {};

  for (var item in CoreBPEConstructor.all.entries) {
    final encName = item.key;
    final constructor = item.value;
    if (_ENCODING_CONSTRUCTORS!.containsKey(encName)) {
      throw TiktokenError(
          "Duplicate encoding name $encName in tiktoken plugin ext");
    }
    _ENCODING_CONSTRUCTORS![encName] = constructor;
  }
}

/// Returns encoding based on encoding name
Tiktoken getEncoding(String encodingName) {
  if (_ENCODINGS.containsKey(encodingName)) {
    return _ENCODINGS[encodingName]!;
  }

  if (_ENCODING_CONSTRUCTORS == null) {
    _getCtor();
    assert(_ENCODING_CONSTRUCTORS != null);
  }

  if (!_ENCODING_CONSTRUCTORS!.containsKey(encodingName)) {
    throw TiktokenError("Unknown encoding $encodingName");
  }

  final constructor = _ENCODING_CONSTRUCTORS![encodingName]!();
  final enc = Tiktoken(
    name: constructor.name,
    patStr: constructor.patStr,
    mergeableRanks: constructor.mergeableRanks,
    explicitNVocab: constructor.explicitNVocab,
    specialTokens: constructor.specialTokens,
  );

  _ENCODINGS[encodingName] = enc;

  return enc;
}

/// Returns all avalilable encoding names
List<String> listEncodingNames() {
  if (_ENCODING_CONSTRUCTORS == null) {
    _getCtor();
    assert(_ENCODING_CONSTRUCTORS != null);
  }

  return _ENCODING_CONSTRUCTORS!.keys.toList();
}
