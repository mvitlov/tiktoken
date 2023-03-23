## Loading an encoding
You can load an encoding by either `encoding name` or by `model name`:

```dart
// 1. Load an encoding by encoding name
final encoding = getEncoding("cl100k_base");
print(encoding.name) // 'cl100k_base'

// 2. Load an encoding by model name
final encoding = encodingForModel("gpt-3.5-turbo");
print(encoding.name) // 'cl100k_base'
```

## Turning text into tokens
For turning text into tokens you can use `encoding.encode()` method:

```dart
final encoding = encodingForModel("gpt-3.5-turbo");
print(encoding.encode("tiktoken is great!")); // [83, 1609, 5963, 374, 2294, 0]
```

Count tokens by counting the length of the list returned by `encode` method:
```dart
/// Returns the number of tokens in a text string.
int numTokensFromString(String string, String encodingName) {
  final encoding = getEncoding(encodingName);
  final numTokens = encoding.encode(string).length;
  return numTokens;
}
print(numTokensFromString("tiktoken is great!", "cl100k_base")); // 6
```

## Turning tokens into text
For turning tokens into text you can use `encoding.decode()` method:
```dart
final encoding = encodingForModel("gpt-3.5-turbo");
print(encoding.decode([83, 1609, 5963, 374, 2294, 0])); // 'tiktoken is great!'
```
*Warning: although `.decode()` can be applied to single tokens, beware that it can be lossy for tokens that aren't on utf-8 boundaries.*

For single tokens, `.decode_single_token_bytes()` safely converts a single integer token to the bytes it represents.
```dart
final encoding = encodingForModel("gpt-3.5-turbo");
final tokens = [83, 1609, 5963, 374, 2294, 0];
final bytes = tokens.map((token) => encoding.decodeSingleTokenBytes(token));
print(bytes.map((e) => utf8.decode(e)).toList()); // ['t', 'ik', 'token',  'is',  'great', '!']
```

## Comparing encodings
Different encodings can vary in how they split words, group spaces, and handle non-English characters. Using the methods above, we can compare different encodings on a few example strings.
```dart
/// Prints a comparison of three string encodings.
void compareEncodings(String exampleString) {
  // print the example string
  print('\nExample string: "$exampleString"');
  // for each encoding, print the number of tokens, the token integers, and the token bytes
  for (var encodingName in ["gpt2", "p50k_base", "cl100k_base"]) {
    final encoding = getEncoding(encodingName);
    final tokenIntegers = encoding.encode(exampleString);
    final numTokens = tokenIntegers.length;
    final tokenBytes = tokenIntegers.map((token) => encoding.decodeSingleTokenBytes(token));
    print("");
    print("$encodingName: $numTokens tokens");
    print("token integers: $tokenIntegers");
    print("token bytes: ${tokenBytes.map(utf8.decode).toList()}");
  }
}

compareEncodings("antidisestablishmentarianism");

// Example string: "antidisestablishmentarianism"

// gpt2: 5 tokens
// token integers: [415, 29207, 44390, 3699, 1042]
// token bytes: ['ant', 'idis', 'establishment', 'arian', 'ism']

// p50k_base: 5 tokens
// token integers: [415, 29207, 44390, 3699, 1042]
// token bytes: ['ant', 'idis', 'establishment', 'arian', 'ism']

// cl100k_base: 6 tokens
// token integers: [519, 85342, 34500, 479, 8997, 2191]
// token bytes: ['ant', 'idis', 'establish', 'ment', 'arian', 'ism']
```