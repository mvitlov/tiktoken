import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tiktoken/src/error/tiktoken_error.dart';
import 'package:tiktoken/src/mappings.dart';
import 'package:tiktoken/tiktoken.dart';

void main() {
  test("encodingForModel", () {
    expect(() => encodingForModel("gpt2"), returnsNormally);
    expect(encodingForModel("gpt2").name, equals("gpt2"));
    expect(encodingForModel("text-davinci-003").name, equals("p50k_base"));
    expect(encodingForModel("gpt-3.5-turbo").name, equals("cl100k_base"));
    expect(
      () => encodingForModel("gpt2-unknown"),
      throwsA(isA<TiktokenError>()),
    );
  });

  test("getEncoding", () {
    expect(() => getEncoding("cl100k_base"), returnsNormally);
    expect(getEncoding("cl100k_base").name, equals("cl100k_base"));
    expect(() => getEncoding("unknown"), throwsA(isA<TiktokenError>()));
  });

  group('simple', () {
    test('roundtrip', () {
      for (var name in listEncodingNames()) {
        final tiktoken = getEncoding(name);
        for (var token in List.generate(10000, (i) => i)) {
          expect(
              tiktoken
                  .encodeSingleToken(tiktoken.decodeSingleTokenBytes(token)),
              token);
        }
      }
    });
  });

  group("gpt2", () {
    final enc = getEncoding("gpt2");

    test("encodes hello world string", () {
      expect(
        enc.encode("hello world"),
        orderedEquals(Uint32List.fromList([31373, 995])),
      );
    });

    test("decodes hello world string", () {
      expect(
          utf8.decode(
            enc.decodeBytes(Uint32List.fromList([31373, 995])),
          ),
          equals("hello world"));
    });

    test("encodes hello world string, all allowed special characters", () {
      expect(
        enc.encode(
          "hello <|endoftext|>",
          allowedSpecial: SpecialTokensSet.all(),
        ),
        orderedEquals(Uint32List.fromList([31373, 220, 50256])),
      );
    });
  });

  group("cl100k_base", () {
    final enc = getEncoding("cl100k_base");

    test("encodes hello world string", () {
      expect(
        enc.encode("hello world"),
        orderedEquals(Uint32List.fromList([15339, 1917])),
      );
    });

    test("decodes hello world string", () {
      expect(
          utf8.decode(
            enc.decodeBytes(Uint32List.fromList([15339, 1917])),
          ),
          equals("hello world"));
    });

    test("encodes hello world string, all allowed special characters", () {
      expect(
        enc.encode(
          "hello <|endoftext|>",
          allowedSpecial: SpecialTokensSet.all(),
        ),
        orderedEquals(Uint32List.fromList([15339, 220, 100257])),
      );
    });
  });

  test("custom special tokens", () {
    final gpt2 = getEncoding("gpt2");

    final custom = Tiktoken(
      name: "custom",
      patStr: gpt2.patStr,
      mergeableRanks: gpt2.mergeableRanks,
      specialTokens: {
        ...gpt2.specialTokens,
        "<|im_start|>": 100264,
        "<|im_end|>": 100265,
      },
    );

    expect(
        custom.encode(
          "<|im_start|>test<|im_end|>",
          allowedSpecial: SpecialTokensSet.all(),
        ),
        orderedEquals(Uint32List.fromList([100264, 9288, 100265])));
  });

  test("encode string tokens", () {
    final core = getEncoding("gpt2");

    final enc = Tiktoken(
      name: "gpt2_im",
      patStr: core.patStr,
      mergeableRanks: core.mergeableRanks,
      specialTokens: {...core.specialTokens, "<|im_start|>": 100264},
    );

    expect(
      enc.encode("hello world"),
      orderedEquals(Uint32List.fromList([31373, 995])),
    );

    expect(
      enc.encode(
        "<|endoftext|>",
        allowedSpecial: SpecialTokensSet.custom({"<|endoftext|>"}),
      ),
      orderedEquals(Uint32List.fromList([50256])),
    );

    expect(
      enc.encode("<|endoftext|>", allowedSpecial: SpecialTokensSet.all()),
      orderedEquals(Uint32List.fromList([50256])),
    );

    expect(() => enc.encode("<|endoftext|>"), throwsA(isA<TiktokenError>()));

    expect(() => enc.encode("<|im_start|>"), throwsA(isA<TiktokenError>()));

    expect(
      enc.encode(
        "<|endoftext|>",
        allowedSpecial: SpecialTokensSet.empty(),
        disallowedSpecial: SpecialTokensSet.empty(),
      ),
      orderedEquals(Uint32List.fromList([27, 91, 437, 1659, 5239, 91, 29])),
    );
  });
}
