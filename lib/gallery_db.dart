import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sqflite/sqflite.dart";

import "models.dart";

class GalleryDb {
  Database? _db;
  late Directory folder;

  Future<void> open() async {
    if (_db != null) return;
    final docs = await getApplicationDocumentsDirectory();
    folder = Directory(p.join(docs.path, "gallery"));
    await folder.create(recursive: true);
    _db = await openDatabase(
      p.join(docs.path, "granth_gallery.db"),
      version: 1,
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE items (
            id TEXT PRIMARY KEY,
            kind TEXT,
            title TEXT,
            text TEXT,
            topic TEXT,
            granth TEXT,
            folderId TEXT,
            createdAt INTEGER,
            size INTEGER,
            fileName TEXT,
            filePath TEXT,
            previewPath TEXT
          )
        """);
        await db.execute("CREATE TABLE folders (id TEXT PRIMARY KEY, name TEXT)");
      },
    );
  }

  Future<List<GalleryItem>> items() async {
    await open();
    final rows = await _db!.query("items", orderBy: "createdAt DESC");
    return rows.map(_item).toList();
  }

  Future<List<({String id, String name})>> folders() async {
    await open();
    final rows = await _db!.query("folders", orderBy: "name COLLATE NOCASE");
    return [for (final row in rows) (id: row["id"] as String, name: row["name"] as String)];
  }

  Future<void> addFolder(String name) async {
    await open();
    final id = "f${DateTime.now().microsecondsSinceEpoch}";
    await _db!.insert("folders", {"id": id, "name": name.trim()});
  }

  Future<void> renameFolder(String id, String name) async {
    await open();
    await _db!.update("folders", {"name": name.trim()}, where: "id = ?", whereArgs: [id]);
  }

  Future<void> deleteFolder(String id) async {
    await open();
    await _db!.update("items", {"folderId": ""}, where: "folderId = ?", whereArgs: [id]);
    await _db!.delete("folders", where: "id = ?", whereArgs: [id]);
  }

  Future<void> setFolder(String itemId, String folderId) async {
    await open();
    await _db!.update("items", {"folderId": folderId}, where: "id = ?", whereArgs: [itemId]);
  }

  Future<GalleryItem> save({
    required String id,
    required String kind,
    required String title,
    required String text,
    required String topic,
    required String granth,
    required List<int> bytes,
    required String fileName,
    List<int>? preview,
  }) async {
    await open();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]+'), " ").replaceAll(RegExp(r"\s+"), " ").trim();
    final file = File(p.join(folder.path, "$id-$safeName"));
    await file.writeAsBytes(bytes, flush: true);
    var previewPath = "";
    if (preview != null && preview.isNotEmpty) {
      final shot = File(p.join(folder.path, "$id-preview.jpg"));
      await shot.writeAsBytes(preview, flush: true);
      previewPath = shot.path;
    } else if (kind == "image") {
      previewPath = file.path;
    }
    final item = GalleryItem(
      id: id,
      kind: kind,
      title: title,
      text: text,
      topic: topic,
      granth: granth,
      folderId: "",
      createdAt: DateTime.now().millisecondsSinceEpoch,
      size: bytes.length,
      fileName: safeName,
      filePath: file.path,
      previewPath: previewPath,
    );
    await _db!.insert(
      "items",
      {
        "id": item.id,
        "kind": item.kind,
        "title": item.title,
        "text": item.text,
        "topic": item.topic,
        "granth": item.granth,
        "folderId": item.folderId,
        "createdAt": item.createdAt,
        "size": item.size,
        "fileName": item.fileName,
        "filePath": item.filePath,
        "previewPath": item.previewPath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return item;
  }

  Future<void> delete(GalleryItem item) async {
    await open();
    await _db!.delete("items", where: "id = ?", whereArgs: [item.id]);
    for (final path in [item.filePath, item.previewPath]) {
      if (path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  GalleryItem _item(Map<String, Object?> row) => GalleryItem(
        id: row["id"] as String,
        kind: row["kind"] as String? ?? "image",
        title: row["title"] as String? ?? "",
        text: row["text"] as String? ?? "",
        topic: row["topic"] as String? ?? "",
        granth: row["granth"] as String? ?? "",
        folderId: row["folderId"] as String? ?? "",
        createdAt: row["createdAt"] as int? ?? 0,
        size: row["size"] as int? ?? 0,
        fileName: row["fileName"] as String? ?? "",
        filePath: row["filePath"] as String? ?? "",
        previewPath: row["previewPath"] as String? ?? "",
      );
}
