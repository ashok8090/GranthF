import "dart:io";

import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";

import "app_model.dart";
import "bridge.dart";
import "media.dart";
import "models.dart";
import "nav.dart";
import "order.dart";
import "pdf_maker.dart";
import "search.dart";
import "ui.dart";

class DashboardPage extends StatelessWidget {
  final void Function(Dest dest) go;
  const DashboardPage({super.key, required this.go});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 22, 88),
      children: [
        const Text("Dashboard", style: TextStyle(fontSize: 28, color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
        const Text("Overview of your Granth collection", style: TextStyle(color: muted, fontFamily: "NotoSansDevanagari")),
        const SizedBox(height: 14),
        _dash(context, "Topics", app.topics.length, Icons.assignment_outlined, saffron, () => go(Dest.topics)),
        _dash(context, "Granths", app.granths.length, Icons.menu_book, maroon, () => go(Dest.granths)),
        _dash(context, "प्रमाण", app.pramans.length, Icons.image_outlined, gold, () => go(Dest.pramans)),
        const SizedBox(height: 8),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("सत साहेब जी", style: TextStyle(fontSize: 20, color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
              const SizedBox(height: 8),
              const Text(
                "जो प्रमाण समय पर याद नहीं रहते, यह ग्रंथ प्रबंधन उन्हें विषय और ग्रंथ के साथ एक जगह रखता है। पहली बार इंटरनेट पर खुलते ही विषय, ग्रंथ और प्रमाण इस डिवाइस पर सेव हो जाते हैं — उसके बाद ऐप बिना नेट के खुलता है।",
                style: TextStyle(color: ink, height: 1.45, fontFamily: "NotoSansDevanagari"),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () => openExternal("mailto:sadgranthpraman@gmail.com"),
                child: const Text("संपर्क: sadgranthpraman@gmail.com", style: TextStyle(color: maroon, decoration: TextDecoration.underline, fontFamily: "NotoSansDevanagari")),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dash(BuildContext context, String label, int count, IconData icon, Color tone, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: tone == gold ? brown : tone, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(count == 0 ? "—" : "$count", style: const TextStyle(fontSize: 28, color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
                  Text(label, style: const TextStyle(color: brown, fontSize: 16, fontFamily: "NotoSansDevanagari")),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: gold),
          ],
        ),
      ),
    );
  }
}

class TopicPage extends StatelessWidget {
  final void Function(Dest dest) go;
  final void Function(PdfRequest request) onPdf;
  const TopicPage({super.key, required this.go, required this.onPdf});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return CatalogBrowser<Topic>(
      memoryKey: "topics",
      title: "Topics",
      subtitle: "विषय / प्रश्नोत्तरी",
      hint: "विषय खोजें — mans, गीता, मृत्यु",
      items: app.topics,
      doc: (item) => app.topicDocs[item.id] ?? prepare([item.title, item.description]),
      cols: app.topicCols,
      choices: const [1, 2],
      onCols: (value) => app.setCols(topic: value),
      emptyTitle: "कोई विषय नहीं",
      emptyBody: "सिंक पूरा होने पर विषय यहाँ दिखेंगे।",
      card: (item, index, total) {
        final proofs = int.tryParse(item.pramanCount) ?? 0;
        return SoftCard(
          onTap: () => go(Dest("pramans", topicId: item.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${item.position}. ${item.title}", maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: maroon, fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, fontFamily: "NotoSansDevanagari")),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, height: 1.35, fontFamily: "NotoSansDevanagari")),
              ],
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (proofs > 0) Pill("$proofs प्रमाण", hot: true, icon: Icons.image_outlined, onTap: () => go(Dest("pramans", topicId: item.id))),
                  if (proofs > 0) Pill("$index/$total", icon: Icons.menu_book_outlined),
                  Pill("Share", icon: Icons.share, onTap: () => shareHash(item.title, "/pramans?topic=${item.id}")),
                  Pill("PDF", hot: true, onTap: () => onPdf(requestForTopic(app, item, app.pdfStyle))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class GranthPage extends StatelessWidget {
  final void Function(Dest dest) go;
  final void Function(List<String> paths) onOpen;
  final void Function(PdfRequest request) onPdf;
  final Future<void> Function(String path, String title) onSaveImage;
  const GranthPage({super.key, required this.go, required this.onOpen, required this.onPdf, required this.onSaveImage});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return CatalogBrowser<Granth>(
      memoryKey: "granths",
      title: "Granths",
      subtitle: "Sacred texts and scriptures",
      hint: "ग्रंथ का नाम — gita, kabir",
      items: app.granths,
      doc: (item) => app.granthDocs[item.id] ?? prepare([item.title, item.author, item.description]),
      cols: app.granthCols,
      choices: const [1, 2, 3],
      onCols: (value) => app.setCols(granth: value),
      emptyTitle: "कोई ग्रंथ नहीं",
      emptyBody: "सिंक के बाद पवित्र ग्रंथ यहाँ खुलेंगे।",
      card: (item, index, total) {
        final proofs = int.tryParse(item.pramanCount) ?? 0;
        final shots = [item.imagePath, item.editorImagePath].map(mediaPath).whereType<String>().toList();
        return SoftCard(
          onTap: () => go(Dest("pramans", granthId: item.id)),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: maroon, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, fontFamily: "NotoSansDevanagari")),
              if (item.author.isNotEmpty) Text(item.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12, fontFamily: "NotoSansDevanagari")),
              const SizedBox(height: 6),
              Expanded(
                child: Shot(
                  path: item.imagePath,
                  height: double.infinity,
                  onTap: shots.isEmpty ? null : () => onOpen(shots),
                  onSave: mediaPath(item.imagePath) == null ? null : () => onSaveImage(item.imagePath, item.title),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (proofs > 0) Pill("$proofs प्रमाण", hot: true, icon: Icons.image_outlined),
                  Pill("$index/$total", icon: Icons.menu_book_outlined),
                  Pill("Share", icon: Icons.share, onTap: () => shareHash(item.title, "/pramans?granth=${item.id}")),
                  if (item.granthUrl.isNotEmpty) Pill("Original PDF", onTap: () => openExternal(item.granthUrl)),
                  Pill("हाईलाइट PDF", hot: true, onTap: () => onPdf(requestForGranth(app, item, app.pdfStyle))),
                  if (app.offlineIds.contains(item.id)) const Pill("ऑफलाइन"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class PramanPage extends StatelessWidget {
  final Dest dest;
  final void Function(Dest dest) go;
  final void Function(List<String> paths) onOpen;
  final void Function(PdfRequest request) onPdf;
  final Future<void> Function(String path, String title) onSaveImage;
  const PramanPage({super.key, required this.dest, required this.go, required this.onOpen, required this.onPdf, required this.onSaveImage});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Topic? topic;
    Granth? granth;
    for (final item in app.topics) {
      if (item.id == dest.topicId) topic = item;
    }
    for (final item in app.granths) {
      if (item.id == dest.granthId) granth = item;
    }
    final rows = app.pramans.where((item) {
      if (dest.topicId != null && item.topicId != dest.topicId) return false;
      if (dest.granthId != null && item.granthId != dest.granthId) return false;
      if (dest.pramanId != null && item.id != dest.pramanId) return false;
      return true;
    }).toList();
    final sorted = sortPramans(rows, granth?.title ?? "");
    return CatalogBrowser<Praman>(
      memoryKey: "pramans:${dest.granthId ?? ""}:${dest.topicId ?? ""}:${dest.pramanId ?? ""}",
      title: "प्रमाण",
      subtitle: "शास्त्र प्रमाण",
      hint: "प्रमाण खोजें — mans, मृत्यु",
      items: sorted,
      doc: (item) => app.pramanDocs[item.id] ?? prepare([item.title, item.description, item.topicTitle, item.granthTitle]),
      cols: app.pramanCols,
      choices: const [1, 2],
      onCols: (value) => app.setCols(praman: value),
      emptyTitle: "कोई प्रमाण नहीं",
      emptyBody: "इस चयन में प्रमाण नहीं मिले, या सिंक अभी चल रहा है।",
      banner: topic == null && granth == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 22, 0),
              child: SoftCard(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          if (topic != null) "विषय: ${topic.title}",
                          if (granth != null) "ग्रंथ: ${granth.title}",
                        ].join("\n"),
                        style: const TextStyle(color: brown, fontFamily: "NotoSansDevanagari"),
                      ),
                    ),
                    Pill("सभी प्रमाण", onTap: () => go(Dest.pramans)),
                  ],
                ),
              ),
            ),
      card: (item, index, total) {
        final shots = [item.imagePath, item.granthImage, item.editorImagePath].map(mediaPath).whereType<String>().toList();
        final video = youtubeId(item.youtubeUrl);
        final start = int.tryParse(item.youtubeStart) ?? 0;
        return SoftCard(
          onTap: shots.isEmpty ? null : () => onOpen(shots),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Shot(path: item.granthImage, height: 72, onTap: shots.isEmpty ? null : () => onOpen(shots), onSave: mediaPath(item.granthImage) == null ? null : () => onSaveImage(item.granthImage, item.granthTitle))),
                  const SizedBox(width: 6),
                  Expanded(child: Shot(path: item.editorImagePath, height: 72, onTap: shots.isEmpty ? null : () => onOpen(shots))),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: maroon, fontWeight: FontWeight.w700, height: 1.3, fontFamily: "NotoSansDevanagari")),
              if (item.favorite == "1") const Text("मुख्य", style: TextStyle(color: saffronDark, fontSize: 12, fontFamily: "NotoSansDevanagari")),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (item.topicTitle.isNotEmpty) Pill(item.topicTitle, onTap: () => go(Dest("pramans", topicId: item.topicId))),
                  if (item.granthTitle.isNotEmpty) Pill(item.granthTitle, onTap: () => go(Dest("pramans", granthId: item.granthId))),
                  Pill("$index/$total"),
                  Pill("Share", icon: Icons.share, onTap: () => shareHash(item.title, "/pramans?id=${item.id}")),
                  Pill("PDF", hot: true, onTap: () => onPdf(requestForPraman(item, app.pdfStyle))),
                  if (video != null) Pill(start > 0 ? "वीडियो चलाएँ (${start}s)" : "वीडियो चलाएँ", onTap: () => openExternal("https://www.youtube.com/watch?v=$video&t=${start}s")),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class CatalogBrowser<T> extends StatefulWidget {
  final String memoryKey;
  final String title;
  final String subtitle;
  final String hint;
  final List<T> items;
  final Prepared Function(T item) doc;
  final int cols;
  final List<int> choices;
  final ValueChanged<int> onCols;
  final Widget Function(T item, int index, int total) card;
  final String emptyTitle;
  final String emptyBody;
  final Widget? banner;
  const CatalogBrowser({
    super.key,
    required this.memoryKey,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.items,
    required this.doc,
    required this.cols,
    required this.choices,
    required this.onCols,
    required this.card,
    required this.emptyTitle,
    required this.emptyBody,
    this.banner,
  });

  @override
  State<CatalogBrowser<T>> createState() => _CatalogBrowserState<T>();
}

class _CatalogBrowserState<T> extends State<CatalogBrowser<T>> {
  late final TextEditingController text;
  late final ScrollController scroll;
  String applied = "";

  @override
  void initState() {
    super.initState();
    applied = PlaceMemory.queries[widget.memoryKey] ?? "";
    text = TextEditingController(text: applied);
    scroll = ScrollController(initialScrollOffset: PlaceMemory.offsets[widget.memoryKey] ?? 0);
  }

  @override
  void dispose() {
    if (scroll.hasClients) PlaceMemory.offsets[widget.memoryKey] = scroll.offset;
    PlaceMemory.queries[widget.memoryKey] = text.text;
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  List<T> visible() {
    final needles = needlesFor(applied);
    if (needles.isEmpty) return widget.items;
    final ranked = <(T, int)>[];
    for (final item in widget.items) {
      final doc = widget.doc(item);
      if (!matches(doc, needles)) continue;
      ranked.add((item, matchRank(doc, needles)));
    }
    ranked.sort((a, b) => a.$2.compareTo(b.$2));
    return ranked.map((item) => item.$1).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = visible();
    final aspect = widget.cols == 1 ? 0.78 : widget.cols == 2 ? 0.62 : 0.52;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 26, color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
              Text(widget.subtitle, style: const TextStyle(color: muted, fontFamily: "NotoSansDevanagari")),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final size in widget.choices)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Pill("$size×$size", hot: widget.cols == size, onTap: () => widget.onCols(size)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                style: const TextStyle(fontFamily: "NotoSansDevanagari", color: ink),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: muted, fontFamily: "NotoSansDevanagari"),
                  filled: true,
                  fillColor: paper,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: creamDark)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: creamDark)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: gold, width: 1.4)),
                ),
                onChanged: (value) => setState(() => applied = value),
              ),
            ],
          ),
        ),
        if (widget.banner != null) widget.banner!,
        Expanded(
          child: Stack(
            children: [
              rows.isEmpty
                  ? ListView(controller: scroll, children: [
                      const SizedBox(height: 40),
                      Center(child: Text(widget.emptyTitle, style: const TextStyle(color: maroon, fontSize: 18, fontFamily: "NotoSansDevanagari"))),
                      const SizedBox(height: 6),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(widget.emptyBody, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontFamily: "NotoSansDevanagari"))),
                    ])
                  : GridView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 22, 88),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: aspect,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, index) => widget.card(rows[index], index + 1, rows.length),
                    ),
              ScrollRail(controller: scroll),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => GalleryPageState();
}

class GalleryPageState extends State<GalleryPage> {
  String kind = "pdf";
  String query = "";
  String folder = "";
  List<GalleryItem> items = [];
  List<({String id, String name})> folders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) reload();
    });
  }

  Future<void> reload() async {
    final app = AppScope.of(context);
    items = await app.gallery.items();
    folders = await app.gallery.folders();
    if (mounted) setState(() {});
  }

  Future<void> remove(GalleryItem item) async {
    if (item.kind == "pdf") {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: paper,
          title: const Text("क्या आप यह PDF हटाना चाहते हैं?", style: TextStyle(fontFamily: "NotoSansDevanagari", color: maroon)),
          content: Text(item.fileName, style: const TextStyle(fontFamily: "NotoSansDevanagari")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("नहीं")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("हटाएँ")),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    await AppScope.of(context).gallery.delete(item);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final needles = needlesFor(query);
    final shown = items.where((item) {
      if (item.kind != kind) return false;
      if (folder.isNotEmpty && item.folderId != folder) return false;
      if (needles.isEmpty) return true;
      return matches(prepare([item.title, item.fileName]), needles);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ऐप गैलरी", style: TextStyle(fontSize: 26, color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
              const SizedBox(height: 8),
              Row(
                children: [
                  Pill("PDF", hot: kind == "pdf", onTap: () => setState(() => kind = "pdf")),
                  const SizedBox(width: 6),
                  Pill("चित्र", hot: kind == "image", onTap: () => setState(() => kind = "image")),
                  const Spacer(),
                  Pill(app.galleryCols == 1 ? "1×1" : "2×2", onTap: () => app.setCols(gallery: app.galleryCols == 1 ? 2 : 1)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Pill("सभी", hot: folder.isEmpty, onTap: () => setState(() => folder = "")),
                    const SizedBox(width: 6),
                    for (final item in folders) ...[
                      Pill(item.name, hot: folder == item.id, onTap: () => setState(() => folder = item.id)),
                      const SizedBox(width: 6),
                    ],
                    Pill("फोल्डर", onTap: () async {
                      final name = await askText(context, "फोल्डर का नाम");
                      if (name == null || name.trim().isEmpty) return;
                      await app.gallery.addFolder(name);
                      await reload();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(fontFamily: "NotoSansDevanagari"),
                decoration: InputDecoration(
                  hintText: "गैलरी खोजें — mans, गीता",
                  filled: true,
                  fillColor: paper,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text("अभी खाली है", style: TextStyle(color: maroon, fontFamily: "NotoSansDevanagari")))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 22, 88),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: app.galleryCols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final item = shown[index];
                    return SoftCard(
                      onTap: () => openItem(context, item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _preview(item)),
                          const SizedBox(height: 6),
                          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: maroon, fontWeight: FontWeight.w700, fontFamily: "NotoSansDevanagari")),
                          Text(hindiWhen(item.createdAt), style: const TextStyle(color: muted, fontSize: 11, fontFamily: "NotoSansDevanagari")),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pill(item.kind == "pdf" ? "PDF खोलें" : "खोलें", hot: true, onTap: () => openItem(context, item)),
                              Pill("शेयर", onTap: () => SharePlus.instance.share(ShareParams(files: [XFile(item.filePath)], subject: item.title))),
                              Pill("सेव", onTap: () => FilesBridge.publish(item.filePath, item.fileName, pictures: item.kind == "image", mime: item.kind == "pdf" ? "application/pdf" : "image/jpeg")),
                              Pill("हटाएँ", onTap: () => remove(item)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _preview(GalleryItem item) {
    final path = item.previewPath.isNotEmpty ? item.previewPath : (item.kind == "image" ? item.filePath : "");
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(path), width: double.infinity, fit: BoxFit.cover));
    }
    return Container(
      decoration: BoxDecoration(color: maroon, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(item.title, textAlign: TextAlign.center, style: const TextStyle(color: goldLight, fontFamily: "NotoSansDevanagari")),
    );
  }

  Future<void> openItem(BuildContext context, GalleryItem item) async {
    if (item.kind == "pdf") {
      await FilesBridge.open(item.filePath, "application/pdf");
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: paper,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(File(item.filePath), fit: BoxFit.contain),
              const SizedBox(height: 8),
              Text(item.title, style: const TextStyle(fontFamily: "NotoSansDevanagari", color: maroon, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("बंद")),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> askText(BuildContext context, String title) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: paper,
      title: Text(title, style: const TextStyle(fontFamily: "NotoSansDevanagari")),
      content: TextField(controller: controller, autofocus: true, style: const TextStyle(fontFamily: "NotoSansDevanagari")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("नहीं")),
        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("ठीक")),
      ],
    ),
  );
  controller.dispose();
  return value;
}
