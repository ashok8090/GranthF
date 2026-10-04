import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";

import "media.dart";
import "models.dart";

class CatalogSnapshot {
  final List<Topic> topics;
  final List<Granth> granths;
  final List<Praman> pramans;
  final int syncedAt;
  const CatalogSnapshot(this.topics, this.granths, this.pramans, this.syncedAt);

  Map<String, dynamic> toJson() => {
        "syncedAt": syncedAt,
        "topics": topics.map((item) => item.toJson()).toList(),
        "granths": granths.map((item) => item.toJson()).toList(),
        "pramans": pramans.map((item) => item.toJson()).toList(),
      };

  factory CatalogSnapshot.fromJson(Map<String, dynamic> json) => CatalogSnapshot(
        [for (final item in (json["topics"] as List? ?? const [])) Topic.fromJson(Map<String, dynamic>.from(item as Map))],
        [for (final item in (json["granths"] as List? ?? const [])) Granth.fromJson(Map<String, dynamic>.from(item as Map))],
        [for (final item in (json["pramans"] as List? ?? const [])) Praman.fromJson(Map<String, dynamic>.from(item as Map))],
        json["syncedAt"] as int? ?? 0,
      );
}

class CatalogStore {
  final client = http.Client();
  Directory? root;
  final files = <String, String>{};

  Future<Directory> dir() async {
    if (root != null) return root!;
    final base = await getApplicationSupportDirectory();
    final folder = Directory("${base.path}/granth-cache");
    final images = Directory("${folder.path}/images");
    await images.create(recursive: true);
    root = folder;
    if (await images.exists()) {
      await for (final entity in images.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final path = name.replaceAll("__", "/");
        if (path.contains("/")) files[path] = entity.path;
      }
    }
    return folder;
  }

  Future<CatalogSnapshot?> read() async {
    final file = File("${(await dir()).path}/catalog.json");
    if (!await file.exists()) return null;
    try {
      return CatalogSnapshot.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(CatalogSnapshot snapshot) async {
    final file = File("${(await dir()).path}/catalog.json");
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<List<Map<String, dynamic>>> pullList(String request) async {
    final response = await client.get(Uri.parse("$origin/api/index.php?request=$request")).timeout(const Duration(seconds: 40));
    if (response.statusCode != 200) throw Exception("$request failed");
    final body = jsonDecode(response.body);
    if (body is! Map || body["success"] != true || body["data"] is! List) throw Exception("$request empty");
    return [for (final item in body["data"] as List) Map<String, dynamic>.from(item as Map)];
  }

  Future<CatalogSnapshot> pull() async {
    final lists = await Future.wait([
      pullList("getTopics"),
      pullList("getGranths"),
      pullList("getPramans"),
    ]);
    return CatalogSnapshot(
      lists[0].map(Topic.fromJson).toList(),
      lists[1].map(Granth.fromJson).toList(),
      lists[2].map(Praman.fromJson).toList(),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String? localFile(String? raw) {
    final path = mediaPath(raw);
    if (path == null) return null;
    return files[path];
  }

  Future<bool> cacheImage(String raw) async {
    final path = mediaPath(raw);
    if (path == null) return false;
    if (files.containsKey(path)) {
      final existing = File(files[path]!);
      if (await existing.exists() && await existing.length() > 32) return true;
    }
    try {
      final response = await client.get(Uri.parse(mediaUrl(path))).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 || response.bodyBytes.length < 32) return false;
      final type = response.headers["content-type"] ?? "";
      if (type.isNotEmpty && !type.startsWith("image/")) return false;
      final folder = await dir();
      final name = path.replaceAll("/", "__");
      final file = File("${folder.path}/images/$name");
      await file.writeAsBytes(response.bodyBytes, flush: false);
      files[path] = file.path;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<int>?> bytes(String? raw) async {
    final path = mediaPath(raw);
    if (path == null) return null;
    final local = files[path];
    if (local != null) {
      final file = File(local);
      if (await file.exists()) return file.readAsBytes();
    }
    final ok = await cacheImage(path);
    if (!ok) return null;
    return File(files[path]!).readAsBytes();
  }
}

List<String> collectImagePaths(CatalogSnapshot snapshot) {
  final paths = <String>{};
  void push(String value) {
    final path = mediaPath(value);
    if (path != null) paths.add(path);
  }

  for (final granth in snapshot.granths) {
    push(granth.imagePath);
    push(granth.editorImagePath);
  }
  for (final praman in snapshot.pramans) {
    push(praman.imagePath);
    push(praman.granthImage);
    push(praman.editorImagePath);
  }
  return paths.toList();
}
