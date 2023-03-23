import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

final random = Random.secure();

void main() async {
  try {
    Directory("./lib/src/ranks").deleteSync(recursive: true);
  } catch (e) {
    //pass
  }

  await dumpTiktokenBpe(
    await dataGymToMergeableBpeRanks(
      "https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/vocab.bpe",
      "https://openaipublic.blob.core.windows.net/gpt-2/encodings/main/encoder.json",
    ),
    "./lib/src/ranks/gpt2.tiktoken",
    "gpt2",
  );

  await dumpTiktokenBpe(
    await loadTiktokenBpe(
        "https://openaipublic.blob.core.windows.net/encodings/r50k_base.tiktoken"),
    "./lib/src/ranks/r50k_base.tiktoken",
    "r50kBase",
  );

  await dumpTiktokenBpe(
    await loadTiktokenBpe(
        "https://openaipublic.blob.core.windows.net/encodings/p50k_base.tiktoken"),
    "./lib/src/ranks/p50k_base.tiktoken",
    "p50kBase",
  );

  await dumpTiktokenBpe(
    await loadTiktokenBpe(
        "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken"),
    "./lib/src/ranks/cl100k_base.tiktoken",
    "cl100kBase",
  );

  stdout.writeln("Downloaded all encodings OK!");

  File("./lib/src/ranks/index.dart").writeAsStringSync([
    "export 'gpt2.tiktoken.dart';",
    "export 'cl100k_base.tiktoken.dart';",
    "export 'r50k_base.tiktoken.dart';",
    "export 'p50k_base.tiktoken.dart';",
  ].join("\n"));

  stdout.writeln("Generated ranks index file OK!");

  Process.runSync("dart", ["format", "./lib/src/ranks/"]);
}

Future<String> readFile(String blobpath) async {
  if (!blobpath.startsWith("http://") && !blobpath.startsWith("https://")) {
    return File(blobpath).readAsString();
  }
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(blobpath));
  final response = await request.close();

  final contents = Uint8List(response.contentLength);
  var len = response.contentLength;
  var received = 0;

  final iterator = StreamIterator(response);

  while (await iterator.moveNext()) {
    var data = iterator.current;
    var length = data.length;
    received += length;

    contents.setRange(received - length, received, data);

    stdout.write("\r$blobpath "
        "${((received / len) * 100).toStringAsFixed(1)}%  (${(received / 1024).toStringAsFixed(2)} kb / ${(len / 1024).toStringAsFixed(2)} kb)");
  }
  client.close();

  stdout.writeln("\nDowloaded ${blobpath.split("/").last} OK!");
  return utf8.decode(contents);
}

Future<Map<Uint8List, int>> dataGymToMergeableBpeRanks(
  String vocabBpeFile,
  String encoderBpeFile,
) async {
  bool isPrintable(int c) => !(c <= 31 || (c >= 127 && c <= 160) || c == 173);

  final rankToByte = List<int>.generate(256, (i) => i)
      .where((byte) => isPrintable(byte) && String.fromCharCode(byte) != ' ')
      .toList();

  final dataGymByteToByte = Map<String, int>.fromEntries(
    rankToByte
        .map((byte) => MapEntry<String, int>(String.fromCharCode(byte), byte)),
  );

  var n = 0;

  for (var b = 0; b < 256; b++) {
    if (!rankToByte.contains(b)) {
      rankToByte.add(b);
      dataGymByteToByte[String.fromCharCode(256 + n)] = b;
      n += 1;
    }
  }

  assert(rankToByte.length == 256);

  // vocab_bpe contains the merges along with associated ranks
  final vocabBpeContents = await readFile(vocabBpeFile);
  final split = vocabBpeContents.trim().split("\n").sublist(1);

  final bpeMerges = split.map((str) => [str.split(' ')[0], str.split(' ')[1]]);

  String decodeDataGym(String value) {
    var list = <int>[];
    for (var b in value.codeUnits) {
      var byte = dataGymByteToByte[String.fromCharCode(b)]!;
      list.add(byte);
    }

    return String.fromCharCodes(list);
  }

  final bpeRanks = <String, int>{
    for (final e in rankToByte.asMap().entries)
      String.fromCharCode(e.value): e.key,
  };

  n = bpeRanks.length;

  for (final merge in bpeMerges) {
    final first = decodeDataGym(merge.first);
    final second = decodeDataGym(merge.last);
    bpeRanks[first + second] = n;
    n += 1;
  }

  final encoderJson = jsonDecode(
    await readFile(encoderBpeFile),
  ) as Map<String, dynamic>;

  final encoderJsonLoaded = <String, int>{
    for (var entry in encoderJson.entries) decodeDataGym(entry.key): entry.value
  };

  // Remove the two special tokens if they are present
  encoderJsonLoaded.removeWhere((key, _) => key == "<|endoftext|>");
  encoderJsonLoaded.removeWhere((key, _) => key == "<|startoftext|>");

  assert(_mapEquals(encoderJsonLoaded, bpeRanks));

  return bpeRanks.map((k, v) => MapEntry(Uint8List.fromList(k.codeUnits), v));
}

Future<void> dumpTiktokenBpe(
  Map<Uint8List, int> bpeRanks,
  String tiktokenBpeFile,
  String varName,
) async {
  print("Writing $tiktokenBpeFile...");
  final codeFile = File("$tiktokenBpeFile.dart");

  await Directory(tiktokenBpeFile).parent.create(recursive: true);

  var entries = bpeRanks.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final codeLines = <String>[];

  for (var item in entries) {
    final token = item.key;
    final rank = item.value;
    codeLines.add("'#': $rank,".replaceFirst("#", base64.encode(token)));
  }

  var codeFileContents = "final $varName = <String,int>{#};"
      .replaceFirst("#", codeLines.join("\n"));

  await codeFile.writeAsString(codeFileContents);
}

Future<Map<Uint8List, int>> loadTiktokenBpe(String tiktokenBpeFile) async {
  //   # NB: do not add caching to this function
  var contents = await readFile(tiktokenBpeFile);

  var lines = LineSplitter.split(contents);

  var map = <Uint8List, int>{};

  for (var line in lines) {
    var s = line.split(" ");
    var token = s.first;
    var rang = s.last;

    map[base64.decode(token)] = int.parse(rang);
  }

  return map;
}

bool _mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final T key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) {
      return false;
    }
  }

  return true;
}
