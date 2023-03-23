import 'package:test/test.dart';
import 'package:tiktoken/src/error/tiktoken_error.dart';
import 'package:tiktoken/src/mappings.dart';

void main() {
  group('mappings', () {
    test('finds correct encoding for model name', () {
      expect(encodingForModel("gpt-3.5-turbo-0301").name, "cl100k_base");
      expect(encodingForModel("ada").name, "r50k_base");
      expect(encodingForModel("cushman-codex").name, "p50k_base");
      expect(encodingForModel("code-davinci-edit-001").name, "p50k_edit");
    });

    test('throws on unknown model name', () {
      expect(() => encodingForModel(""), throwsA(isA<TiktokenError>()));
      expect(() => encodingForModel("hello"), throwsA(isA<TiktokenError>()));
      expect(() => encodingForModel("gpt-5"), throwsA(isA<TiktokenError>()));
    });
  });
}
