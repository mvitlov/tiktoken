# ⏳ tiktoken

tiktoken is a [BPE](https://en.wikipedia.org/wiki/Byte_pair_encoding) tokeniser for use with
OpenAI's models.



Splitting text strings into tokens is useful because GPT models see text in the form of tokens. Knowing how many tokens are in a text string can tell you **a)** whether the string is too long for a text model to process and **b)** how much an OpenAI API call costs (as usage is priced by token). Different models use different encodings.

## Features
The main `Tiktoken` class exposes APIs that allow you to process text using tokens, which are common sequences of character found in text. Some of the things you can do with `tiktoken` package are:
- Encode text into tokens
- Decode tokens into text
- Compare different encodings
- Count tokens for chat API calls

## Usage

For more examples, see the `/example` folder.

```dart
import 'package:tiktoken/toktoken.dart';

// Load an encoding
final encoding = encodingForModel("gpt-3.5-turbo");

// Tokenize text
print(encoding.encode("tiktoken is great!")); // [83, 1609, 5963, 374, 2294, 0]

// Decode tokens
print(encoding.decode([83, 1609, 5963, 374, 2294, 0])); // "tiktoken is great!"
```

## Extending tiktoken
You may wish to extend `Tiktoken` to support new encodings. You can do this by passing around the existing model:
```dart
import 'package:tiktoken/toktoken.dart';

// Create a base
final cl100kBase = encodingForModel("cl100k_base");

// Instantiate a new encoding and extend the base params
final encoding = Tiktoken(
  name: "cl100k_im",
  patStr: cl100kBase.patStr,
  mergeableRanks: cl100kBase.mergeableRanks,
  specialTokens: {
    ...cl100kBase.specialTokens,
    "<|im_start|>": 100264,
    "<|im_end|>": 100265,
  },
);
```


## Additional information

This is a `Dart` port from the original [tiktoken](https://github.com/openai) library written in `Rust`/`Python`.
