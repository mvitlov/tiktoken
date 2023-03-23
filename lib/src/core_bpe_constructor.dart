import 'dart:convert';

import 'package:tiktoken/src/common/byte_array.dart';

import 'ranks/index.dart' as ranks;

// ignore: constant_identifier_names
const ENDOFTEXT = "<|endoftext|>";

// ignore: constant_identifier_names
const FIM_PREFIX = "<|fim_prefix|>";

// ignore: constant_identifier_names
const FIM_MIDDLE = "<|fim_middle|>";

// ignore: constant_identifier_names
const FIM_SUFFIX = "<|fim_suffix|>";

// ignore: constant_identifier_names
const ENDOFPROMPT = "<|endofprompt|>";

class CoreBPEConstructor {
  const CoreBPEConstructor._({
    required this.name,
    required this.patStr,
    required this.mergeableRanks,
    required this.specialTokens,
    this.explicitNVocab,
  });

  factory CoreBPEConstructor.gpt2() {
    return CoreBPEConstructor._(
      name: "gpt2",
      explicitNVocab: 50257,
      patStr:
          r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+",
      mergeableRanks: ranks.gpt2.map(
        (k, v) => MapEntry(ByteArray.fromList(base64Decode(k)), v),
      ),
      specialTokens: {ENDOFTEXT: 50256},
    );
  }

  factory CoreBPEConstructor.r50kBase() {
    return CoreBPEConstructor._(
      name: "r50k_base",
      explicitNVocab: 50257,
      patStr:
          r"""'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+""",
      mergeableRanks: ranks.r50kBase.map(
        (k, v) => MapEntry(ByteArray.fromList(base64Decode(k)), v),
      ),
      specialTokens: {ENDOFTEXT: 50256},
    );
  }

  factory CoreBPEConstructor.p50kBase() {
    return CoreBPEConstructor._(
      name: "p50k_base",
      explicitNVocab: 50281,
      patStr:
          r"""'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+""",
      mergeableRanks: ranks.p50kBase.map(
        (k, v) => MapEntry(ByteArray.fromList(base64Decode(k)), v),
      ),
      specialTokens: {ENDOFTEXT: 50256},
    );
  }

  factory CoreBPEConstructor.p50kEdit() {
    return CoreBPEConstructor._(
      name: "p50k_edit",
      patStr:
          r"""'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+""",
      mergeableRanks: ranks.p50kBase.map(
        (k, v) => MapEntry(ByteArray.fromList(base64Decode(k)), v),
      ),
      specialTokens: {
        ENDOFTEXT: 50256,
        FIM_PREFIX: 50281,
        FIM_MIDDLE: 50282,
        FIM_SUFFIX: 50283
      },
    );
  }

  factory CoreBPEConstructor.cl100kBase() {
    return CoreBPEConstructor._(
      name: "cl100k_base",
      patStr:
          r"(\?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+",
      mergeableRanks: ranks.cl100kBase.map(
        (k, v) => MapEntry(ByteArray.fromList(base64Decode(k)), v),
      ),
      specialTokens: {
        ENDOFTEXT: 100257,
        FIM_PREFIX: 100258,
        FIM_MIDDLE: 100259,
        FIM_SUFFIX: 100260,
        ENDOFPROMPT: 100276,
      },
    );
  }

  final String name;
  final String patStr;
  final Map<ByteArray, int> mergeableRanks;
  final Map<String, int> specialTokens;
  final int? explicitNVocab;

  static const all = {
    "gpt2": CoreBPEConstructor.gpt2,
    "r50k_base": CoreBPEConstructor.r50kBase,
    "p50k_base": CoreBPEConstructor.p50kBase,
    "p50k_edit": CoreBPEConstructor.p50kEdit,
    "cl100k_base": CoreBPEConstructor.cl100kBase,
  };
}
