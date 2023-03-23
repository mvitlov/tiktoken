import 'dart:io';

const ranksDir = "./lib/src/ranks/";
String template(String name) => "final $name = <String,int>{};";

// k:fileName, v:varName
const ranks = {
  "gpt2": "gpt2",
  "cl100k_base": "cl100kBase",
  "p50k_base": "p50kBase",
  "r50k_base": "r50kBase",
};

void main(List<String> args) {
  deleteRanks();
  createRankPlaceholders();

  Process.runSync("dart", ["format", "./lib/src/ranks/"]);
}

void deleteRanks() {
  final dir = Directory(ranksDir);
  if (dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

void createRankPlaceholders() {
  final dir = Directory(ranksDir);

  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final fileNames = <String>[];

  for (var rank in ranks.entries) {
    final content = template(rank.value);
    File("$ranksDir${rank.key}.tiktoken.dart").writeAsStringSync(content);
    fileNames.add("${rank.key}.tiktoken.dart");
  }

  File("${ranksDir}index.dart").writeAsStringSync(
    fileNames.map((fileName) => "export '$fileName';").join("\n"),
  );
}
