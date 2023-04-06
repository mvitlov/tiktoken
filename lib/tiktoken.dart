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

Tiktoken getEncoding(String encodingName) {
  if (_ENCODINGS.containsKey(encodingName)) {
    return _ENCODINGS[encodingName]!;
  }

  late CoreBPEConstructor constructor;

  switch (encodingName) {
    case "cl100k_base":
      constructor = CoreBPEConstructor.cl100kBase();
      break;
    case "gpt2":
      constructor = CoreBPEConstructor.gpt2();
      break;
    case "r50k_base":
      constructor = CoreBPEConstructor.r50kBase();
      break;
    case "p50k_base":
      constructor = CoreBPEConstructor.p50kBase();
      break;
    case "p50k_edit":
      constructor = CoreBPEConstructor.p50kEdit();
      break;
    default:
      throw TiktokenError("Unknown encoding $encodingName");
  }

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
Set<String> listEncodingNames() => CoreBPEConstructor.all;
