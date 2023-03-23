import 'package:tiktoken/src/error/tiktoken_error.dart';
import 'package:tiktoken/tiktoken.dart';

// ignore: constant_identifier_names
const _MODEL_PREFIX_TO_ENCODING = {
  // chat
  "gpt-3.5-turbo-": "cl100k_base" // e.g, gpt-3.5-turbo-0301, -0401, etc.
};

// ignore: constant_identifier_names
const _MODEL_TO_ENCODING = {
  // chat
  "gpt-3.5-turbo": "cl100k_base",
  // text
  "text-davinci-003": "p50k_base",
  "text-davinci-002": "p50k_base",
  "text-davinci-001": "r50k_base",
  "text-curie-001": "r50k_base",
  "text-babbage-001": "r50k_base",
  "text-ada-001": "r50k_base",
  "davinci": "r50k_base",
  "curie": "r50k_base",
  "babbage": "r50k_base",
  "ada": "r50k_base",
  // code
  "code-davinci-002": "p50k_base",
  "code-davinci-001": "p50k_base",
  "code-cushman-002": "p50k_base",
  "code-cushman-001": "p50k_base",
  "davinci-codex": "p50k_base",
  "cushman-codex": "p50k_base",
  // edit
  "text-davinci-edit-001": "p50k_edit",
  "code-davinci-edit-001": "p50k_edit",
  // embeddings
  "text-embedding-ada-002": "cl100k_base",
  // old embeddings
  "text-similarity-davinci-001": "r50k_base",
  "text-similarity-curie-001": "r50k_base",
  "text-similarity-babbage-001": "r50k_base",
  "text-similarity-ada-001": "r50k_base",
  "text-search-davinci-doc-001": "r50k_base",
  "text-search-curie-doc-001": "r50k_base",
  "text-search-babbage-doc-001": "r50k_base",
  "text-search-ada-doc-001": "r50k_base",
  "code-search-babbage-code-001": "r50k_base",
  "code-search-ada-code-001": "r50k_base",
  // open source
  "gpt2": "gpt2",
};

/// Returns the encoding used by a model
Tiktoken encodingForModel(String modelName) {
  String? encodingName;

  if (_MODEL_TO_ENCODING.containsKey(modelName)) {
    encodingName = _MODEL_TO_ENCODING[modelName]!;
  } else {
    for (var item in _MODEL_PREFIX_TO_ENCODING.entries) {
      final modelPrefix = item.key;
      final modelEncodingName = item.value;

      if (modelName.startsWith(modelPrefix)) {
        return getEncoding(modelEncodingName);
      }
    }
  }

  if (encodingName == null) {
    throw TiktokenError(
        "Could not automatically map $modelName to a tokeniser. "
        "Please use `getEncoding` to explicitly get the tokeniser you expect.");
  }

  return getEncoding(encodingName);
}
