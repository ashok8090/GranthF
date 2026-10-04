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
        const Text("Dashboard", style: pageTitle),
        const Text("Overview of your Granth collection", style: subTitle),
        const SizedBox(height: 14),
        _dash(context, "Topics", app.topics.length, Icons.assignment_outlined, saffron, () => go(Dest.topics)),
        _dash(context, "Granths", app.granths.length, Icons.menu_book, maroon, () => go(Dest.granths)),
        _dash(context, "प्रमाण", app.pramans.length, Icons.image_outlined, gold, () => go(Dest.pramans)),
        const SizedBox(height: 8),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("सत साहेब जी", style: TextStyle(fontSize: 22, height: 1.2, color: maroon, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari")),
              const SizedBox(height: 8),
              const Text(
                "जो प्रमाण समय पर याद नहीं रहते, यह ग्रंथ प्रबंधन उन्हें विषय और ग्रंथ के साथ एक जगह रखता है। पहली बार इंटरनेट पर खुलते ही विषय, ग्रंथ और प्रमाण इस डिवाइस पर सेव हो जाते हैं — उसके बाद ऐप बिना नेट के खुलता है।",
                style: TextStyle(color: ink, height: 1.55, fontSize: 14, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari"),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: () => openExternal("mailto:sadgranthpraman@gmail.com"),
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(color: ink, fontSize: 14, fontFamily: "NotoSansDevanagari", decoration: TextDecoration.none),
                    children: [
                      TextSpan(text: "संपर्क: "),
                      TextSpan(text: "sadgranthpraman@gmail.com", style: TextStyle(color: saffronDark, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
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
                  Text(count == 0 ? "—" : "$count", style: const TextStyle(fontSize: 32, height: 1, color: maroon, fontWeight: FontWeight.w400, fontFamily: "NotoSansDevanagari")),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: muted, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: "NotoSansDevanagari")),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${item.position}. ${item.title}", style: cardTitle),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.description, style: cardBody),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: creamDark),
              const SizedBox(height: 8),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.title, style: app.granthCols == 3 ? cardTitle.copyWith(fontSize: 13) : cardTitle.copyWith(fontSize: app.granthCols == 2 ? 15 : 16)),
              if (item.author.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.author, style: authorStyle),
              ],
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: cardBody),
              ],
              const SizedBox(height: 8),
              Shot(
                path: item.imagePath,
                height: app.granthCols >= 3 ? 88 : 120,
                onTap: shots.isEmpty ? null : () => onOpen(shots),
                onSave: mediaPath(item.imagePath) == null ? null : () => onSaveImage(item.imagePath, item.title),
              ),
              const SizedBox(height: 8),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(width: 64, child: Shot(path: item.granthImage, height: 52, onTap: shots.isEmpty ? null : () => onOpen(shots), onSave: mediaPath(item.granthImage) == null ? null : () => onSaveImage(item.granthImage, item.granthTitle))),
                  const SizedBox(width: 6),
                  SizedBox(width: 64, child: Shot(path: item.editorImagePath, height: 52, onTap: shots.isEmpty ? null : () => onOpen(shots))),
                  if (item.favorite == "1") const Spacer(),
                  if (item.favorite == "1") const Text("मुख्य", style: TextStyle(color: maroon, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: "NotoSansDevanagari")),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.title, style: cardTitle),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.description, style: cardBody),
              ],
              const SizedBox(height: 8),
              Shot(path: item.imagePath, height: 150, fit: BoxFit.contain, onTap: shots.isEmpty ? null : () => onOpen(shots), onSave: mediaPath(item.imagePath) == null ? null : () => onSaveImage(item.imagePath, item.title)),
              const SizedBox(height: 8),
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
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: creamDark, width: 1.5));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _toneBox(widget.title),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: pageTitle),
                        Text(widget.subtitle, style: subTitle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: creamDark)),
                    child: Row(
                      children: [
                        for (final size in widget.choices)
                          Pressable(
                            onTap: () => widget.onCols(size),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 42, minHeight: 32),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: widget.cols == size ? maroon : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Text("$size×$size", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.cols == size ? paper : maroon, fontFamily: "NotoSansDevanagari")),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: text,
                      style: const TextStyle(fontFamily: "NotoSansDevanagari", color: ink, fontSize: 14, fontWeight: FontWeight.w400),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: const TextStyle(color: muted, fontFamily: "NotoSansDevanagari", fontSize: 14),
                        filled: true,
                        fillColor: paper,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(borderSide: const BorderSide(color: saffron, width: 1.5)),
                      ),
                      onChanged: (value) => setState(() => applied = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (widget.banner != null) widget.banner!,
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(12, 4, 16, 88),
                itemCount: rows.isEmpty ? 1 : (rows.length / widget.cols).ceil(),
                itemBuilder: (context, row) {
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 36),
                      child: Column(
                        children: [
                          Text(widget.emptyTitle, style: pageTitle.copyWith(fontSize: 18)),
                          const SizedBox(height: 6),
                          Text(widget.emptyBody, textAlign: TextAlign.center, style: subTitle),
                        ],
                      ),
                    );
                  }
                  final start = row * widget.cols;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < widget.cols; column++) ...[
                          if (column > 0) const SizedBox(width: 8),
                          Expanded(child: start + column < rows.length ? widget.card(rows[start + column], start + column + 1, rows.length) : const SizedBox()),
                        ],
                      ],
                    ),
                  );
                },
              ),
              ScrollRail(controller: scroll),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _toneBox(String title) {
  final goldTone = title.contains("प्रमाण");
  final maroonTone = title == "Granths";
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: goldTone ? const [goldLight, gold] : maroonTone ? const [maroonLight, maroon] : const [saffron, saffronDark],
      ),
    ),
    child: Icon(goldTone ? Icons.image_outlined : maroonTone ? Icons.menu_book : Icons.assignment_outlined, color: goldTone ? brown : paper, size: 22),
  );
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
              const Text("ऐप गैलरी", style: pageTitle),
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
