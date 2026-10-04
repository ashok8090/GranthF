import "dart:async";

import "package:flutter/widgets.dart";
import "package:shared_preferences/shared_preferences.dart";

import "catalog.dart";
import "gallery_db.dart";
import "media.dart";
import "models.dart";
import "search.dart";

class AppModel extends ChangeNotifier {
  final store = CatalogStore();
  final gallery = GalleryDb();
  List<Topic> topics = [];
  List<Granth> granths = [];
  List<Praman> pramans = [];
  final topicDocs = <String, Prepared>{};
  final granthDocs = <String, Prepared>{};
  final pramanDocs = <String, Prepared>{};
  String status = "booting";
  String? error;
  bool online = true;
  int? syncedAt;
  int imageDone = 0;
  int imageTotal = 0;
  bool imageRunning = false;
  bool booted = false;
  String look = "combo";
  String pdfStyle = "fill90";
  int topicCols = 1;
  int granthCols = 2;
  int pramanCols = 1;
  int galleryCols = 2;
  final offlineIds = <String>{};
  int _imageToken = 0;
  Timer? _ticker;
  int _lastSync = 0;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    look = prefs.getString("granth-look") ?? "combo";
    pdfStyle = prefs.getString("pdf-style") ?? "fill90";
    topicCols = prefs.getInt("topic-cols") ?? 1;
    granthCols = prefs.getInt("granth-cols") ?? 2;
    pramanCols = prefs.getInt("praman-cols") ?? 1;
    galleryCols = prefs.getInt("gallery-cols") ?? 2;
    offlineIds.addAll(prefs.getStringList("granth-offline-ids") ?? const []);
    final cached = await store.read();
    if (cached != null) {
      _apply(cached);
      status = "ready";
    }
    booted = true;
    notifyListeners();
    await sync();
    _ticker ??= Timer.periodic(const Duration(seconds: 180), (_) => sync(quiet: true));
  }

  void _apply(CatalogSnapshot snapshot) {
    topics = [...snapshot.topics]..sort((a, b) => byPosition(a.position).compareTo(byPosition(b.position)));
    granths = [...snapshot.granths]..sort((a, b) => byPosition(a.position).compareTo(byPosition(b.position)));
    pramans = snapshot.pramans;
    syncedAt = snapshot.syncedAt;
    topicDocs
      ..clear()
      ..addEntries(topics.map((item) => MapEntry(item.id, prepare([item.title, item.description]))));
    granthDocs
      ..clear()
      ..addEntries(granths.map((item) => MapEntry(item.id, prepare([item.title, item.author, item.description]))));
    pramanDocs
      ..clear()
      ..addEntries(pramans.map((item) => MapEntry(item.id, prepare([item.title, item.description, item.topicTitle, item.granthTitle, item.granthAuthor, item.youtubeDesc]))));
  }

  Future<void> sync({bool quiet = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (quiet && now - _lastSync < 3000) return;
    _lastSync = now;
    status = "syncing";
    error = null;
    online = true;
    notifyListeners();
    try {
      final pulled = await store.pull();
      await store.write(pulled);
      _apply(pulled);
      status = "ready";
      error = null;
      notifyListeners();
      unawaited(savePages());
    } catch (_) {
      online = topics.isNotEmpty || granths.isNotEmpty;
      if (topics.isEmpty && granths.isEmpty && pramans.isEmpty) {
        status = "error";
        error = "डेटा नहीं आ पाया। इंटरनेट चेक करके फिर सिंक करें।";
      } else {
        status = "ready";
        error = "नया डेटा नहीं मिला। सेव की हुई कॉपी चल रही है।";
        online = false;
      }
      notifyListeners();
    }
  }

  Future<void> savePages() async {
    final token = ++_imageToken;
    final paths = collectImagePaths(CatalogSnapshot(topics, granths, pramans, syncedAt ?? 0));
    imageTotal = paths.length;
    imageDone = paths.where(store.files.containsKey).length;
    imageRunning = true;
    notifyListeners();
    var since = 0;
    Future<void> worker(String path) async {
      if (token != _imageToken) return;
      final ok = await store.cacheImage(path);
      if (token != _imageToken) return;
      if (ok) imageDone = store.files.length.clamp(0, imageTotal);
      since += 1;
      if (since >= 6) {
        since = 0;
        notifyListeners();
      }
    }

    final pending = paths.where((path) => !store.files.containsKey(path)).toList();
    const width = 6;
    var index = 0;
    Future<void> pump() async {
      while (index < pending.length && token == _imageToken) {
        final path = pending[index];
        index += 1;
        await worker(path);
      }
    }

    await Future.wait([for (var i = 0; i < width; i++) pump()]);
    if (token != _imageToken) return;
    imageDone = paths.where(store.files.containsKey).length;
    imageRunning = false;
    if (imageTotal > 0 && imageDone >= imageTotal) {
      offlineIds.addAll(granths.map((item) => item.id));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("granth-offline-ids", offlineIds.toList());
    }
    notifyListeners();
  }

  Future<void> setLook(String value) async {
    look = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("granth-look", value);
  }

  Future<void> setPdfStyle(String value) async {
    pdfStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("pdf-style", value);
    notifyListeners();
  }

  Future<void> setCols({int? topic, int? granth, int? praman, int? gallery}) async {
    final prefs = await SharedPreferences.getInstance();
    if (topic != null) {
      topicCols = topic;
      await prefs.setInt("topic-cols", topic);
    }
    if (granth != null) {
      granthCols = granth;
      await prefs.setInt("granth-cols", granth);
    }
    if (praman != null) {
      pramanCols = praman;
      await prefs.setInt("praman-cols", praman);
    }
    if (gallery != null) {
      galleryCols = gallery;
      await prefs.setInt("gallery-cols", gallery);
    }
    notifyListeners();
  }

  Future<void> markOffline(Iterable<String> ids) async {
    offlineIds.addAll(ids.where((id) => id.isNotEmpty));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("granth-offline-ids", offlineIds.toList());
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    store.client.close();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel notifier, required super.child, super.key}) : super(notifier: notifier);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, "AppScope missing");
    return scope!.notifier!;
  }
}
