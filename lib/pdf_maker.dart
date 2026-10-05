import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image/image.dart" as im;
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "app_model.dart";
import "models.dart";
import "order.dart";

class PdfLeaf {
  final String title;
  final String subtitle;
  final String body;
  final String meta;
  final String? imagePath;
  final bool topicCover;
  const PdfLeaf({
    required this.title,
    this.subtitle = "",
    this.body = "",
    this.meta = "",
    this.imagePath,
    this.topicCover = false,
  });
}

class PdfRequest {
  final String title;
  final String fileName;
  final String style;
  final List<PdfLeaf> leaves;
  final String galleryId;
  final String topic;
  final String granth;
  final List<String> offlineIds;
  const PdfRequest({
    required this.title,
    required this.fileName,
    required this.style,
    required this.leaves,
    required this.galleryId,
    this.topic = "",
    this.granth = "",
    this.offlineIds = const [],
  });
}

class PdfProgress {
  final String phase;
  final int done;
  final int total;
  final int millis;
  const PdfProgress(this.phase, this.done, this.total, this.millis);
}

class PdfBuilt {
  final Uint8List bytes;
  final Uint8List? preview;
  final int pages;
  final int millis;
  const PdfBuilt(this.bytes, this.preview, this.pages, this.millis);
}

class PdfCancelled implements Exception {}

bool _fontReady = false;

Future<void> ensureDevanagari() async {
  if (_fontReady) return;
  final loader = FontLoader("NotoSansDevanagari")..addFont(rootBundle.load("assets/fonts/NotoSansDevanagari-Regular.ttf"));
  await loader.load();
  _fontReady = true;
}

Map<String, Object> _fitJpeg(Map<String, Object> args) {
  final raw = args["b"] as Uint8List;
  final maxSide = args["m"] as int;
  final quality = args["q"] as int;
  final decoded = im.decodeImage(raw);
  if (decoded == null) {
    return {"b": raw, "w": 0, "h": 0};
  }
  var img = im.bakeOrientation(decoded);
  final longest = img.width > img.height ? img.width : img.height;
  if (longest > maxSide) {
    img = img.width >= img.height ? im.copyResize(img, width: maxSide) : im.copyResize(img, height: maxSide);
  }
  return {
    "b": Uint8List.fromList(im.encodeJpg(img, quality: quality)),
    "w": img.width,
    "h": img.height,
  };
}

Future<({Uint8List bytes, int w, int h})?> fitJpeg(List<int> raw, {required int maxSide, required int quality}) async {
  final fitted = await compute(_fitJpeg, {"b": Uint8List.fromList(raw), "m": maxSide, "q": quality});
  final bytes = fitted["b"] as Uint8List;
  final w = fitted["w"] as int;
  final h = fitted["h"] as int;
  if (w <= 0 || h <= 0) return null;
  return (bytes: bytes, w: w, h: h);
}

Future<_RasterText> _paragraphPng({
  required String text,
  required double width,
  required double size,
  required Color color,
  TextAlign align = TextAlign.center,
}) async {
  await ensureDevanagari();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const heightFactor = 1.48;
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      fontFamily: "NotoSansDevanagari",
      fontSize: size,
      textAlign: align,
      height: heightFactor,
    ),
  )..pushStyle(ui.TextStyle(fontFamily: "NotoSansDevanagari", fontSize: size, color: color, height: heightFactor));
  builder.addText(text.trim().isEmpty ? " " : text.trim());
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));
  final padTop = size * 0.34;
  final padBottom = size * 0.5;
  final height = paragraph.height + padTop + padBottom;
  canvas.drawParagraph(paragraph, Offset(0, padTop));
  final image = await recorder.endRecording().toImage(width.ceil(), height.ceil().clamp(1, 12000));
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return _RasterText(data!.buffer.asUint8List(), width.ceil(), height.ceil());
}

class _RasterText {
  final Uint8List bytes;
  final int w;
  final int h;
  const _RasterText(this.bytes, this.w, this.h);
}

Future<_RasterText> _fitText({
  required String text,
  required double contentW,
  required double maxH,
  required double startPt,
  required Color color,
}) async {
  const pxW = 1800.0;
  var pt = startPt;
  _RasterText? last;
  while (pt >= 10) {
    final png = await _paragraphPng(text: text, width: pxW, size: pt * (pxW / contentW), color: color);
    last = png;
    final pdfH = contentW * png.h / png.w;
    if (pdfH <= maxH) return png;
    pt -= 0.7;
  }
  return last!;
}

double _pdfTextHeight(_RasterText? png, double contentW) {
  if (png == null || png.w <= 0) return 0;
  return contentW * png.h / png.w;
}

Future<Uint8List> topicCoverPng(String title, String body) async {
  await ensureDevanagari();
  const width = 900.0;
  const height = 1272.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xfff6efe2));
  void wash(Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48));
  }

  wash(const Offset(140, 220), 180, const Color(0x66e8821a));
  wash(const Offset(760, 980), 220, const Color(0x557b1f2e));
  wash(const Offset(480, 640), 160, const Color(0x44c9a84c));
  final outer = RRect.fromRectAndRadius(const Rect.fromLTWH(36, 36, width - 72, height - 72), const Radius.circular(18));
  final inner = RRect.fromRectAndRadius(const Rect.fromLTWH(52, 52, width - 104, height - 104), const Radius.circular(12));
  canvas.drawRRect(outer, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = const Color(0xff7b1f2e));
  canvas.drawRRect(inner, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xffc9a84c));
  final titlePaint = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontFamily: "NotoSansDevanagari", fontSize: 54, textAlign: TextAlign.center, maxLines: 6, height: 1.25),
  )..pushStyle(ui.TextStyle(fontFamily: "NotoSansDevanagari", color: const Color(0xff6d1826), fontSize: 54, height: 1.25));
  titlePaint.addText(title.trim().isEmpty ? "विषय" : title.trim());
  final titleParagraph = titlePaint.build()..layout(const ui.ParagraphConstraints(width: 700));
  canvas.drawParagraph(titleParagraph, Offset(100, (height - titleParagraph.height) / 2 - 40));
  if (body.trim().isNotEmpty) {
    final bodyPaint = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontFamily: "NotoSansDevanagari", fontSize: 26, textAlign: TextAlign.center, maxLines: 6, height: 1.3),
    )..pushStyle(ui.TextStyle(fontFamily: "NotoSansDevanagari", color: const Color(0xff4a2c0a), fontSize: 26, height: 1.3));
    bodyPaint.addText(body.trim());
    final bodyParagraph = bodyPaint.build()..layout(const ui.ParagraphConstraints(width: 700));
    canvas.drawParagraph(bodyParagraph, Offset(100, (height + titleParagraph.height) / 2));
  }
  final foot = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: "NotoSansDevanagari", fontSize: 22, textAlign: TextAlign.center))
    ..pushStyle(ui.TextStyle(fontFamily: "NotoSansDevanagari", color: const Color(0xff7b1f2e), fontSize: 22));
  foot.addText("ग्रंथ प्रबंधन");
  final footParagraph = foot.build()..layout(const ui.ParagraphConstraints(width: 700));
  canvas.drawParagraph(footParagraph, Offset(100, height - 120));
  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<PdfBuilt> buildPdf(
  PdfRequest request, {
  required Future<List<int>?> Function(String? path) load,
  required void Function(PdfProgress progress) onProgress,
  required bool Function() cancelled,
}) async {
  final started = DateTime.now();
  void report(String phase, int done, int total) {
    onProgress(PdfProgress(phase, done, total, DateTime.now().difference(started).inMilliseconds));
  }

  final original = request.style == "original";
  final prepared = <({Uint8List? image, int w, int h, _RasterText? header, _RasterText? footer, bool cover})>[];
  final total = request.leaves.length;
  for (var i = 0; i < request.leaves.length; i++) {
    if (cancelled()) throw PdfCancelled();
    final leaf = request.leaves[i];
    report("चित्र बन रहे हैं", i, total);
    if (leaf.topicCover) {
      final cover = await topicCoverPng(leaf.title, leaf.body);
      prepared.add((image: cover, w: 900, h: 1272, header: null, footer: null, cover: true));
      continue;
    }
    final raw = await load(leaf.imagePath);
    ({Uint8List bytes, int w, int h})? shot;
    if (raw != null) {
      shot = await fitJpeg(raw, maxSide: original ? 2200 : 1600, quality: original ? 90 : 84);
    }
    if (original) {
      if (shot != null) prepared.add((image: shot.bytes, w: shot.w, h: shot.h, header: null, footer: null, cover: false));
      continue;
    }
    final landscape = shot != null && shot.w > shot.h * 1.02;
    final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final contentW = format.width - 36;
    final contentH = format.height - 36;
    final textBudget = shot == null ? contentH * 0.86 : contentH * 0.46;
    final headerText = (leaf.body.isNotEmpty ? leaf.body : (leaf.subtitle.isNotEmpty ? leaf.subtitle : leaf.title));
    final footerBits = <String>[
      if (leaf.body.isNotEmpty) leaf.title,
      if (leaf.meta.isNotEmpty && leaf.meta != "आवरण") leaf.meta,
      if (leaf.body.isEmpty && leaf.subtitle.isNotEmpty) leaf.subtitle,
    ].where((bit) => bit.trim().isNotEmpty && bit.trim() != "आवरण");
    final footerText = footerBits.join("\n");
    final headerShare = footerText.trim().isEmpty ? textBudget : textBudget * 0.62;
    final footerShare = textBudget - headerShare;
    final header = headerText.trim().isEmpty
        ? null
        : await _fitText(text: headerText, contentW: contentW, maxH: headerShare, startPt: 15, color: const Color(0xff7b1f2e));
    final footer = footerText.trim().isEmpty
        ? null
        : await _fitText(text: footerText, contentW: contentW, maxH: footerShare, startPt: 12.5, color: const Color(0xff4a2c0a));
    prepared.add((image: shot?.bytes, w: shot?.w ?? 0, h: shot?.h ?? 0, header: header, footer: footer, cover: false));
    await Future<void>.delayed(Duration.zero);
  }
  if (cancelled()) throw PdfCancelled();
  report("पृष्ठ जुड़ रहे हैं", 0, prepared.length);
  final doc = pw.Document();
  final latin = pw.Font.helvetica();
  var pageNo = 0;
  Uint8List? preview;
  for (final page in prepared) {
    if (cancelled()) throw PdfCancelled();
    pageNo += 1;
    if (page.cover && page.image != null) {
      preview ??= page.image;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: [
          pw.Positioned.fill(child: pw.Image(pw.MemoryImage(page.image!), fit: pw.BoxFit.cover)),
          pw.Positioned(
            right: 16,
            bottom: 10,
            child: pw.Text("$pageNo", style: pw.TextStyle(font: latin, fontSize: 11, color: PdfColor.fromInt(0xff7b1f2e))),
          ),
        ]),
      ));
    } else if (original && page.image != null) {
      preview ??= page.image;
      final landscape = page.w > page.h * 1.05;
      final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          const inset = 10.0;
          final boxW = format.width - inset * 2;
          final boxH = format.height - inset * 2;
          var drawW = boxW;
          var drawH = page.w == 0 ? boxH : boxW * page.h / page.w;
          if (drawH > boxH) {
            drawH = boxH;
            drawW = page.h == 0 ? boxW : boxH * page.w / page.h;
          }
          return pw.Center(child: pw.Image(pw.MemoryImage(page.image!), width: drawW, height: drawH));
        },
      ));
    } else {
      preview ??= page.image ?? page.header?.bytes;
      final landscape = page.w > page.h * 1.02 && page.w > 0;
      final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
      final number = pageNo;
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        pageTheme: pw.PageTheme(theme: pw.ThemeData.withFont(base: latin)),
        build: (_) {
          const left = 18.0;
          const top = 14.0;
          const right = 18.0;
          const bottom = 16.0;
          final contentW = format.width - left - right;
          final contentH = format.height - top - bottom;
          var headerH = _pdfTextHeight(page.header, contentW);
          var footerH = _pdfTextHeight(page.footer, contentW);
          var headerW = page.header == null ? 0.0 : contentW;
          var footerW = page.footer == null ? 0.0 : contentW;
          const gap = 6.0;
          const numH = 14.0;
          final room = contentH - gap * 2 - numH;
          final maxText = room - 72 < 40 ? 40.0 : room - 72;
          if (headerH + footerH > maxText && headerH + footerH > 0) {
            final scale = maxText / (headerH + footerH);
            headerH *= scale;
            footerH *= scale;
            headerW *= scale;
            footerW *= scale;
          }
          final imageH = room - headerH - footerH;
          var drawW = contentW;
          var drawH = page.w <= 0 ? imageH : contentW * page.h / page.w;
          if (drawH > imageH) {
            drawH = imageH;
            drawW = page.h <= 0 ? contentW : imageH * page.w / page.h;
          }
          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(left, top, right, bottom),
            child: pw.Column(
              children: [
                if (page.header != null) pw.SizedBox(width: contentW, height: headerH, child: pw.Center(child: pw.Image(pw.MemoryImage(page.header!.bytes), width: headerW, height: headerH))),
                if (page.header != null) pw.SizedBox(height: gap),
                pw.Container(
                  width: contentW,
                  height: imageH < 1 ? 1 : imageH,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: page.image == null ? 0 : 0.6)),
                  alignment: pw.Alignment.center,
                  child: page.image == null ? pw.SizedBox() : pw.Image(pw.MemoryImage(page.image!), width: drawW, height: drawH),
                ),
                if (page.footer != null) pw.SizedBox(height: gap),
                if (page.footer != null) pw.SizedBox(width: contentW, height: footerH, child: pw.Center(child: pw.Image(pw.MemoryImage(page.footer!.bytes), width: footerW, height: footerH))),
                pw.SizedBox(
                  height: numH,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text("$number", style: pw.TextStyle(font: latin, fontSize: 11, color: PdfColor.fromInt(0xff7b1f2e))),
                  ),
                ),
              ],
            ),
          );
        },
      ));
    }
    report("पृष्ठ जुड़ रहे हैं", pageNo, prepared.length);
  }
  if (pageNo == 0) throw Exception("कोई पृष्ठ नहीं बना");
  report("सेव हो रहा है", pageNo, pageNo);
  final bytes = await doc.save();
  return PdfBuilt(bytes, preview, pageNo, DateTime.now().difference(started).inMilliseconds);
}

PdfRequest requestForGranth(AppModel app, Granth granth, String style) {
  final proofs = sortPramans(app.pramans.where((item) => item.granthId == granth.id).toList(), granth.title);
  final leaves = <PdfLeaf>[
    PdfLeaf(title: granth.title, subtitle: granth.author, body: granth.description.isEmpty ? granth.title : granth.description, imagePath: granth.imagePath),
    if (granth.editorImagePath.isNotEmpty)
      PdfLeaf(title: granth.title, subtitle: "प्रकाशन", body: granth.author.isEmpty ? "प्रकाशन विवरण" : "प्रकाशन · ${granth.author}", meta: "प्रकाशन विवरण", imagePath: granth.editorImagePath),
    for (final praman in proofs)
      PdfLeaf(title: praman.title, subtitle: praman.topicTitle, body: praman.description.isEmpty ? praman.topicTitle : praman.description, meta: [praman.granthTitle, praman.granthAuthor].where((bit) => bit.isNotEmpty).join(" · "), imagePath: praman.imagePath),
  ];
  return PdfRequest(
    title: granth.title,
    fileName: pdfFileName(granth.title, "granth-${granth.id}"),
    style: style,
    leaves: leaves,
    galleryId: "pdf-granth-${granth.id}",
    granth: granth.title,
    offlineIds: [granth.id],
  );
}

PdfRequest requestForTopic(AppModel app, Topic topic, String style) {
  final proofs = sortPramans(app.pramans.where((item) => item.topicId == topic.id).toList());
  final byId = {for (final granth in app.granths) granth.id: granth};
  final leaves = <PdfLeaf>[
    PdfLeaf(title: topic.title, subtitle: "विषय", body: topic.description, topicCover: true),
  ];
  final seen = <String>{};
  final offline = <String>[];
  for (final praman in proofs) {
    if (seen.add(praman.granthId)) {
      offline.add(praman.granthId);
      final granth = byId[praman.granthId];
      if (granth != null) {
        leaves.add(PdfLeaf(title: granth.title, subtitle: granth.author, body: granth.description.isEmpty ? granth.title : granth.description, imagePath: granth.imagePath));
        if (granth.editorImagePath.isNotEmpty) {
          leaves.add(PdfLeaf(title: granth.title, subtitle: "प्रकाशन", body: granth.author.isEmpty ? "प्रकाशन विवरण" : "प्रकाशन · ${granth.author}", imagePath: granth.editorImagePath));
        }
      }
    }
    leaves.add(PdfLeaf(
      title: praman.title,
      subtitle: praman.topicTitle,
      body: praman.description.isEmpty ? praman.topicTitle : praman.description,
      meta: [praman.granthTitle, praman.granthAuthor].where((bit) => bit.isNotEmpty).join(" · "),
      imagePath: praman.imagePath,
    ));
  }
  return PdfRequest(
    title: topic.title,
    fileName: pdfFileName(topic.title, "topic-${topic.id}"),
    style: style,
    leaves: leaves,
    galleryId: "pdf-topic-${topic.id}",
    topic: topic.title,
    offlineIds: offline,
  );
}

PdfRequest requestForPraman(Praman praman, String style) => PdfRequest(
      title: praman.title,
      fileName: pdfFileName(praman.title, praman.id),
      style: style,
      galleryId: "pdf-${praman.id}",
      topic: praman.topicTitle,
      granth: praman.granthTitle,
      offlineIds: [praman.granthId],
      leaves: [
        PdfLeaf(
          title: praman.title,
          subtitle: praman.topicTitle,
          body: praman.description,
          meta: [praman.granthTitle, praman.granthAuthor].where((bit) => bit.isNotEmpty).join(" · "),
          imagePath: praman.imagePath,
        ),
      ],
    );

String pdfFileName(String title, String fallback) {
  final clean = title.replaceAll(RegExp(r'[\\/:*?"<>|]+'), " ").replaceAll(RegExp(r"\s+"), " ").trim();
  final clipped = clean.length > 70 ? clean.substring(0, 70).trim() : clean;
  return "${clipped.isEmpty ? fallback : clipped}.pdf";
}

String formatSpan(int millis) {
  final seconds = (millis / 1000).ceil().clamp(1, 9999);
  if (seconds < 60) return "$seconds सेकंड";
  return "${seconds ~/ 60} मि · ${seconds % 60} से";
}

String formatSize(int bytes) {
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}
