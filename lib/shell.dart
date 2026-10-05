import "dart:async";
import "dart:io";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "app_model.dart";
import "bridge.dart";
import "nav.dart";
import "pages.dart";
import "pdf_maker.dart";
import "ui.dart";

const _navChannel = MethodChannel("com.wnm.granthf/nav");

class GranthApp extends StatefulWidget {
  const GranthApp({super.key});

  @override
  State<GranthApp> createState() => _GranthAppState();
}

class _GranthAppState extends State<GranthApp> with WidgetsBindingObserver {
  final stack = <Dest>[Dest.dashboard];
  final galleryKey = GlobalKey<GalleryPageState>();
  bool splash = true;
  bool menu = false;
  bool settings = false;
  bool exitAsk = false;
  bool secret = false;
  int versionTaps = 0;
  List<String>? shots;
  int shotIndex = 0;
  PdfRequest? pdfAsk;
  String? pdfStylePick;
  PdfProgress? pdfProgress;
  PdfBuilt? pdfDone;
  PdfRequest? pdfDoneRequest;
  String? pdfSavedPath;
  bool pdfBusy = false;
  bool cancelPdf = false;
  int lastBack = 0;
  int exitShownAt = 0;
  StreamSubscription<Uri>? links;

  Dest get top => stack.last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => splash = false);
    });
    final appLinks = AppLinks();
    appLinks.getInitialLink().then(openLink);
    links = appLinks.uriLinkStream.listen(openLink);
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == "back" && mounted) onBack();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    links?.cancel();
    _navChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppScope.of(context).sync(quiet: true);
    }
  }

  void openLink(Uri? uri) {
    if (uri == null || !mounted) return;
    final dest = destFromUri(uri);
    if (dest == null) return;
    setState(() {
      if (!dest.same(Dest.dashboard)) stack.add(dest);
      splash = false;
    });
  }

  void go(Dest dest) {
    setState(() {
      menu = false;
      settings = false;
      if (top.same(dest)) return;
      stack.add(dest);
    });
  }

  void home() {
    setState(() {
      stack
        ..clear()
        ..add(Dest.dashboard);
      menu = false;
    });
  }

  bool closeOverlay() {
    if (menu) {
      setState(() => menu = false);
      return true;
    }
    if (settings) {
      setState(() => settings = false);
      return true;
    }
    if (shots != null) {
      setState(() => shots = null);
      return true;
    }
    if (pdfAsk != null) {
      setState(() => pdfAsk = null);
      return true;
    }
    if (pdfDone != null) {
      setState(() => pdfDone = null);
      return true;
    }
    return false;
  }

  void onBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastBack < 320) return;
    lastBack = now;
    if (splash) {
      setState(() => splash = false);
      return;
    }
    if (pdfBusy) {
      cancelPdf = true;
      return;
    }
    if (closeOverlay()) return;
    if (exitAsk) {
      if (now - exitShownAt < 500) return;
      SystemNavigator.pop();
      return;
    }
    if (stack.length > 1) {
      setState(() => stack.removeLast());
      return;
    }
    exitShownAt = now;
    setState(() => exitAsk = true);
  }

  bool headerOn(String which) {
    final route = top;
    if (which == "topics") return route.panel == "topics" || (route.panel == "pramans" && route.topicId != null && route.granthId == null);
    if (which == "granths") return route.panel == "granths" || (route.panel == "pramans" && route.granthId != null);
    return route.panel == "pramans" && route.topicId == null && route.granthId == null;
  }

  Future<void> saveImage(String path, String title) async {
    final app = AppScope.of(context);
    final bytes = await app.store.bytes(path);
    if (bytes == null || !mounted) return;
    final name = pdfFileName(title, "image").replaceAll(".pdf", ".jpg");
    final item = await app.gallery.save(id: "img-$path", kind: "image", title: title, text: "", topic: "", granth: title, bytes: bytes, fileName: name);
    await FilesBridge.publish(item.filePath, item.fileName, pictures: true, mime: "image/jpeg");
    galleryKey.currentState?.reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("एल्बम और ऐप गैलरी में सेव हो गया")));
  }

  Future<void> runPdf(PdfRequest request) async {
    final app = AppScope.of(context);
    setState(() {
      pdfAsk = null;
      pdfBusy = true;
      cancelPdf = false;
      pdfProgress = PdfProgress("चित्र बन रहे हैं", 0, request.leaves.length, 0);
    });
    try {
      final built = await buildPdf(
        request,
        load: app.store.bytes,
        cancelled: () => cancelPdf,
        onProgress: (progress) {
          if (mounted) setState(() => pdfProgress = progress);
        },
      );
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(docs.path, "ready"));
      await folder.create(recursive: true);
      final file = File(p.join(folder.path, "${DateTime.now().millisecondsSinceEpoch}-${request.fileName}"));
      await file.writeAsBytes(built.bytes, flush: true);
      await FilesBridge.publish(file.path, request.fileName, pictures: false, mime: "application/pdf");
      await app.markOffline(request.offlineIds);
      if (!mounted) return;
      setState(() {
        pdfBusy = false;
        pdfProgress = null;
        pdfDone = built;
        pdfDoneRequest = request;
        pdfSavedPath = file.path;
      });
    } on PdfCancelled {
      if (mounted) {
        setState(() {
          pdfBusy = false;
          pdfProgress = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        pdfBusy = false;
        pdfProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Stack(
        children: [
          ColoredBox(
            color: cream,
            child: Column(
              children: [
                _mast(app),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      onTap: () => setState(() => menu = !menu),
                      child: Container(
                        width: 44,
                        height: 40,
                        decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(8), border: Border.all(color: creamDark)),
                        child: Icon(menu ? Icons.close : Icons.menu, color: maroon, size: 22),
                      ),
                    ),
                  ),
                ),
                _sync(app),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation);
                      return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
                    },
                    child: KeyedSubtree(key: ValueKey(top.key), child: _page(app)),
                  ),
                ),
              ],
            ),
          ),
          if (menu) _menu(),
          if (shots != null) _lightbox(),
          if (settings) _settings(app),
          if (exitAsk) _exit(),
          if (pdfAsk != null) _pdfPicker(app),
          if (pdfProgress != null) _pdfRun(),
          if (pdfDone != null) _pdfCard(),
          if (splash) _splash(),
        ],
      ),
    );
  }

  Widget _page(AppModel app) {
    final dest = top;
    if (dest.panel == "topics") return TopicPage(go: go, onPdf: (request) => setState(() => pdfAsk = request));
    if (dest.panel == "granths") {
      return GranthPage(go: go, onPdf: (request) => setState(() => pdfAsk = request), onOpen: (paths) => setState(() { shots = paths; shotIndex = 0; }), onSaveImage: saveImage);
    }
    if (dest.panel == "pramans") {
      return PramanPage(dest: dest, go: go, onPdf: (request) => setState(() => pdfAsk = request), onOpen: (paths) => setState(() { shots = paths; shotIndex = 0; }), onSaveImage: saveImage);
    }
    if (dest.panel == "gallery") return GalleryPage(key: galleryKey);
    return DashboardPage(go: go);
  }

  Widget _headButton(IconData icon, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x88e2c97e))),
        child: Icon(icon, color: goldLight, size: 20),
      ),
    );
  }

  Widget _mast(AppModel app) {
    Widget stat(String which, String label, int count, Dest dest) {
      final on = headerOn(which);
      return Expanded(
        child: Pressable(
          onTap: () => go(dest),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on ? goldLight : const Color(0x59c9a84c)),
              color: on ? const Color(0x47c9a84c) : const Color(0x0fffffff),
            ),
            child: Column(
              children: [
                Text(count == 0 ? "—" : "$count", style: const TextStyle(color: goldLight, fontSize: 20, height: 1.1, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari")),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(color: goldLight, fontSize: 10, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari")),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [maroon, brown, maroonLight]),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              Container(height: 3, margin: const EdgeInsets.only(bottom: 8), decoration: const BoxDecoration(gradient: LinearGradient(colors: [saffronDark, saffron, gold, saffron, saffronDark]))),
              Row(
                children: [
                  Pressable(onTap: home, child: const BrandMark()),
                  const SizedBox(width: 10),
                  const Expanded(child: Text("ग्रंथ प्रबंधन", style: TextStyle(color: goldLight, fontSize: 22, height: 1.15, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari"))),
                  _headButton(Icons.photo_library_outlined, () => go(Dest.gallery)),
                  const SizedBox(width: 6),
                  _headButton(Icons.settings_outlined, () => setState(() => settings = true)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  stat("topics", "विषय / प्रश्नोत्तरी", app.topics.length, Dest.topics),
                  stat("granths", "पवित्र ग्रन्थ", app.granths.length, Dest.granths),
                  stat("pramans", "नए प्रमाण", app.pramans.length, Dest.pramans),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sync(AppModel app) {
    final imageLabel = app.imageTotal == 0
        ? (app.status == "syncing" ? "सूची सेव हो रही है…" : "")
        : app.imageRunning
            ? "पेज सेव हो रहे हैं ${app.imageDone}/${app.imageTotal}"
            : app.imageDone >= app.imageTotal
                ? "सभी पेज इस डिवाइस पर सेव हैं"
                : "सेव पेज ${app.imageDone}/${app.imageTotal}";
    final line = app.status == "syncing"
        ? "ऑनलाइन सिंक हो रहा है — सूची डिवाइस पर लिखी जा रही है"
        : app.error ?? (app.online ? "ऑफलाइन तैयार${app.syncedAt == null ? "" : " · ${hindiWhen(app.syncedAt)}"}" : "इंटरनेट नहीं · सेव किया डेटा चल रहा है");
    return Container(
      color: const Color(0xe6f5e6c8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: app.online ? const Color(0xff2e7d32) : muted),
          const SizedBox(width: 6),
          Expanded(child: Text("$line${imageLabel.isEmpty ? "" : " · $imageLabel"}", style: const TextStyle(color: brown, fontSize: 12, fontFamily: "NotoSansDevanagari"))),
          Pressable(
            onTap: app.status == "syncing" ? null : () => app.sync(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(999), border: Border.all(color: creamDark)),
              child: const Row(
                children: [
                  Icon(Icons.sync, size: 15, color: maroon),
                  SizedBox(width: 4),
                  Text("सिंक", style: TextStyle(color: maroon, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: "NotoSansDevanagari")),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu() {
    Widget item(String label, Dest dest, IconData icon) {
      final on = top.panel == dest.panel && dest.topicId == null;
      return Pressable(
        onTap: () => dest.panel == "dashboard" ? home() : go(dest),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: on ? const Color(0x22c9a84c) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Icon(icon, color: goldLight), const SizedBox(width: 8), Text(label, style: const TextStyle(color: goldLight, fontFamily: "NotoSansDevanagari"))]),
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => menu = false),
        child: ColoredBox(
          color: const Color(0x66000000),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SmoothIn(
              begin: const Offset(-32, 0),
              child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 240,
                color: brown,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    item("Dashboard", Dest.dashboard, Icons.dashboard_outlined),
                    item("Topics", Dest.topics, Icons.assignment_outlined),
                    item("Granths", Dest.granths, Icons.menu_book),
                    item("प्रमाण", Dest.pramans, Icons.image_outlined),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lightbox() {
    final paths = shots ?? const <String>[];
    final index = shotIndex.clamp(0, paths.isEmpty ? 0 : paths.length - 1);
    return Positioned.fill(
      child: SmoothIn(
        begin: Offset.zero,
        duration: const Duration(milliseconds: 220),
        child: ColoredBox(
        color: const Color(0xee1a0c06),
        child: SafeArea(
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => shots = null), child: const Text("बंद", style: TextStyle(color: goldLight)))),
              Expanded(child: paths.isEmpty ? const SizedBox() : Shot(path: paths[index], height: double.infinity, fit: BoxFit.contain)),
              if (paths.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: () => setState(() => shotIndex = (index - 1 + paths.length) % paths.length), icon: const Icon(Icons.chevron_left, color: goldLight)),
                    Text("${index + 1}/${paths.length}", style: const TextStyle(color: goldLight)),
                    IconButton(onPressed: () => setState(() => shotIndex = (index + 1) % paths.length), icon: const Icon(Icons.chevron_right, color: goldLight)),
                  ],
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _settings(AppModel app) {
    Widget block(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: children),
          ]),
        );
    return _sheet(
      "सेटिंग",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block("थीम", [
            for (final look in const [
              ("classic", "सादा"),
              ("combo", "Bento + Clay"),
              ("glass", "Glassmorphism"),
              ("neu", "Neumorphism"),
              ("clay", "Claymorphism"),
              ("material", "Material"),
              ("flat", "Flat"),
              ("bento", "Bento"),
            ])
              Pill(look.$2, hot: app.look == look.$1, onTap: () => app.setLook(look.$1)),
          ]),
          block("PDF सेटिंग", [
            Pill("PDF विषय के साथ", hot: app.pdfStyle == "fill90", onTap: () => app.setPdfStyle("fill90")),
            Pill("केवल चित्र", hot: app.pdfStyle == "original", onTap: () => app.setPdfStyle("original")),
          ]),
          block("लेआउट", [
            Pill("1×1", hot: app.topicCols == 1 && app.granthCols == 1, onTap: () => app.setCols(topic: 1, granth: 1, praman: 1, gallery: 1)),
            Pill("2×2", hot: app.granthCols == 2, onTap: () => app.setCols(topic: 2, granth: 2, praman: 2, gallery: 2)),
          ]),
          Pressable(
            onTap: () {
              versionTaps += 1;
              if (versionTaps >= 5) setState(() => secret = true);
            },
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("Version 1.0.2", style: TextStyle(color: brown, fontFamily: "NotoSansDevanagari"))),
          ),
          if (secret) const Text("डेवलपर मोड", style: TextStyle(color: muted, fontFamily: "NotoSansDevanagari")),
        ],
      ),
      () => setState(() => settings = false),
    );
  }

  Widget _exit() {
    return _sheet(
      "क्या आप बाहर निकलना चाहते हैं?",
      Wrap(
        spacing: 8,
        children: [
          Pill("हाँ, बाहर जाएँ", hot: true, onTap: SystemNavigator.pop),
          Pill("नहीं", onTap: () => setState(() => exitAsk = false)),
        ],
      ),
      () => setState(() => exitAsk = false),
    );
  }

  Widget _pdfPicker(AppModel app) {
    final request = pdfAsk!;
    pdfStylePick ??= app.pdfStyle;
    return _sheet(
      "PDF शैली",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.title, style: const TextStyle(fontFamily: "NotoSansDevanagari", color: brown)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill("PDF विषय के साथ", hot: pdfStylePick == "fill90", onTap: () => setState(() => pdfStylePick = "fill90")),
              Pill("केवल चित्र", hot: pdfStylePick == "original", onTap: () => setState(() => pdfStylePick = "original")),
            ],
          ),
          const SizedBox(height: 8),
          Text(pdfStylePick == "original" ? "सिर्फ़ मूल चित्र, पूरी गुणवत्ता, कोई लिखावट नहीं" : "बड़ा चित्र, विषय ऊपर और पेज नीचे", style: const TextStyle(color: muted, fontFamily: "NotoSansDevanagari")),
          const SizedBox(height: 12),
          Pill("OK", hot: true, onTap: () {
            final style = pdfStylePick ?? "fill90";
            app.setPdfStyle(style);
            final next = PdfRequest(
              title: request.title,
              fileName: request.fileName,
              style: style,
              leaves: request.leaves,
              galleryId: request.galleryId,
              topic: request.topic,
              granth: request.granth,
              offlineIds: request.offlineIds,
            );
            runPdf(next);
          }),
        ],
      ),
      () => setState(() => pdfAsk = null),
    );
  }

  Widget _pdfRun() {
    final progress = pdfProgress!;
    return _sheet(
      progress.phase,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${progress.done}/${progress.total} पृष्ठ", style: const TextStyle(fontFamily: "NotoSansDevanagari", color: brown, fontSize: 18)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress.total == 0 ? null : progress.done / progress.total, color: maroon, backgroundColor: creamDark),
          const SizedBox(height: 8),
          Text("समय ${formatSpan(progress.millis)}", style: const TextStyle(fontFamily: "NotoSansDevanagari", color: muted)),
          const SizedBox(height: 10),
          Pill("रोकें", onTap: () => cancelPdf = true),
        ],
      ),
      () => cancelPdf = true,
    );
  }

  Widget _pdfCard() {
    final built = pdfDone!;
    final request = pdfDoneRequest!;
    final path = pdfSavedPath;
    return _sheet(
      "तैयार",
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${built.pages} पृष्ठ · ${formatSpan(built.millis)} · ${formatSize(built.bytes.length)}", style: const TextStyle(fontFamily: "NotoSansDevanagari", color: brown)),
          const SizedBox(height: 6),
          const Text("Downloads और फ़ाइल मैनेजर में सेव हो गया", style: TextStyle(fontFamily: "NotoSansDevanagari", color: muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill("शेयर", hot: true, onTap: () {
                if (path != null) SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: "application/pdf")], subject: request.title));
              }),
              Pill("ऐप में सेव करें", onTap: () async {
                final app = AppScope.of(context);
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: paper,
                    title: const Text("क्या आप इस PDF को ऐप गैलरी में सेव करना चाहते हैं?", style: TextStyle(fontFamily: "NotoSansDevanagari", color: maroon)),
                    content: Text(request.fileName, style: const TextStyle(fontFamily: "NotoSansDevanagari")),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("नहीं")),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("सेव")),
                    ],
                  ),
                );
                if (yes != true || !mounted) return;
                await app.gallery.save(
                  id: request.galleryId,
                  kind: "pdf",
                  title: request.title,
                  text: "",
                  topic: request.topic,
                  granth: request.granth,
                  bytes: built.bytes,
                  fileName: request.fileName,
                  preview: built.preview,
                );
                galleryKey.currentState?.reload();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ऐप गैलरी में सेव हो गया")));
                setState(() => pdfDone = null);
              }),
              if (path != null) Pill("PDF खोलें", onTap: () => FilesBridge.open(path, "application/pdf")),
            ],
          ),
        ],
      ),
      () => setState(() => pdfDone = null),
    );
  }

  Widget _sheet(String title, Widget child, VoidCallback close) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: close,
        child: ColoredBox(
          color: const Color(0x88000000),
          child: Center(
            child: SmoothIn(
              begin: const Offset(0, 22),
              child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Material(
                  color: paper,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(title, style: const TextStyle(color: maroon, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari"))),
                              Pill("पीछे", onTap: close),
                            ],
                          ),
                          const SizedBox(height: 12),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _splash() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [maroon, brown])),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(22), child: const BrandMark(size: 96)),
              const SizedBox(height: 16),
              const Text("ग्रंथ प्रबंधन", style: TextStyle(color: goldLight, fontSize: 26, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari")),
            ],
          ),
        ),
      ),
    );
  }
}
