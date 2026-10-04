import "dart:async";
import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:url_launcher/url_launcher.dart";

import "app_model.dart";
import "media.dart";

const saffron = Color(0xffe8821a);
const saffronDark = Color(0xffc06a10);
const maroon = Color(0xff7b1f2e);
const maroonLight = Color(0xffa0293d);
const gold = Color(0xffc9a84c);
const goldLight = Color(0xffe2c97e);
const cream = Color(0xfffdf6e3);
const creamDark = Color(0xfff5e6c8);
const brown = Color(0xff4a2c0a);
const ink = Color(0xff3d1f00);
const muted = Color(0xff8b6a4a);
const paper = Color(0xfffffdf7);
const site = "https://granth.grok.me";

const pageTitle = TextStyle(fontFamily: "NotoSansDevanagari", fontSize: 26, height: 1.1, fontWeight: FontWeight.w400, color: maroon);
const subTitle = TextStyle(fontFamily: "NotoSansDevanagari", fontSize: 13, height: 1.3, fontWeight: FontWeight.w400, color: muted);
const cardTitle = TextStyle(fontFamily: "NotoSansDevanagari", fontSize: 16, height: 1.4, fontWeight: FontWeight.w400, color: maroon);
const cardBody = TextStyle(fontFamily: "NotoSansDevanagari", fontSize: 13, height: 1.5, fontWeight: FontWeight.w400, color: muted);
const authorStyle = TextStyle(fontFamily: "NotoSansDevanagari", fontSize: 12, height: 1.3, fontWeight: FontWeight.w600, color: saffronDark);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 46});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [saffron, gold]),
      ),
      alignment: Alignment.center,
      child: CustomPaint(size: Size(size * 0.62, size * 0.62), painter: const _MalaPainter()),
    );
  }
}

class _MalaPainter extends CustomPainter {
  const _MalaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;
    final bead = Paint()..color = maroon;
    for (var i = 0; i < 12; i++) {
      final angle = -1.5708 + i * 6.28318 / 12;
      canvas.drawCircle(center + Offset(radius * math.cos(angle), radius * math.sin(angle)), 2.1, bead);
    }
    canvas.drawCircle(center, 3.4, Paint()..color = goldLight);
    canvas.drawCircle(center, 3.4, Paint()..color = maroon..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlaceMemory {
  static final offsets = <String, double>{};
  static final queries = <String, String>{};
}

BoxDecoration cardDecoration(String look) {
  switch (look) {
    case "classic":
      return BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: creamDark),
        boxShadow: const [BoxShadow(color: Color(0x144a2c0a), blurRadius: 8, offset: Offset(0, 2))],
      );
    case "bento":
      return BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gold, width: 1.4),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [paper, creamDark]),
      );
    case "clay":
      return BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xfff8e7cf),
        boxShadow: const [
          BoxShadow(color: Color(0xffffffff), offset: Offset(0, -1), blurRadius: 0),
          BoxShadow(color: Color(0x337b1f2e), offset: Offset(0, 8), blurRadius: 0),
          BoxShadow(color: Color(0x334a2c0a), blurRadius: 16, offset: Offset(0, 10)),
        ],
      );
    case "glass":
      return BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xb3ffffff),
        border: Border.all(color: const Color(0xccffffff)),
        boxShadow: const [BoxShadow(color: Color(0x224a2c0a), blurRadius: 16, offset: Offset(0, 8))],
      );
    case "neu":
      return const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        color: cream,
        boxShadow: [
          BoxShadow(color: Color(0xffffffff), offset: Offset(-5, -5), blurRadius: 10),
          BoxShadow(color: Color(0x334a2c0a), offset: Offset(5, 5), blurRadius: 10),
        ],
      );
    case "material":
      return BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
      );
    case "flat":
      return BoxDecoration(color: paper, borderRadius: BorderRadius.circular(4), border: Border.all(color: creamDark));
    case "combo":
      return const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(26)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xfffffdf8), Color(0xfff8e7cf)]),
        boxShadow: [
          BoxShadow(color: Color(0xffffffff), offset: Offset(0, -1), blurRadius: 0),
          BoxShadow(color: Color(0x297b1f2e), offset: Offset(0, 8), blurRadius: 0),
          BoxShadow(color: Color(0x1f4a2c0a), blurRadius: 18, offset: Offset(0, 10)),
        ],
      );
    default:
      return BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: creamDark),
        boxShadow: const [BoxShadow(color: Color(0x144a2c0a), blurRadius: 8, offset: Offset(0, 2))],
      );
  }
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(scale: down ? 0.97 : 1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut, child: widget.child),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const SoftCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final look = AppScope.of(context).look;
    return Pressable(
      onTap: onTap,
      child: DecoratedBox(
        decoration: cardDecoration(look),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool hot;
  final IconData? icon;
  const Pill(this.label, {super.key, this.onTap, this.hot = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hot ? const Color(0x1a7b1f2e) : const Color(0x2ec9a84c),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hot ? const Color(0x557b1f2e) : const Color(0x66c9a84c)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: maroon), const SizedBox(width: 4)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: brown, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: "NotoSansDevanagari"))),
        ],
      ),
    );
    if (onTap == null) return child;
    return Pressable(onTap: onTap, child: child);
  }
}

class Shot extends StatelessWidget {
  final String? path;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  const Shot({super.key, required this.path, this.height = 160, this.fit = BoxFit.cover, this.onTap, this.onSave});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final local = app.store.localFile(path);
    final safe = mediaPath(path);
    final h = height.isFinite ? height : null;
    Widget image;
    if (local != null) {
      image = Image.file(File(local), fit: fit, width: double.infinity, height: h, errorBuilder: (_, _, _) => _missing(h ?? 120));
    } else if (safe != null) {
      image = Image.network(mediaUrl(safe), fit: fit, width: double.infinity, height: h, errorBuilder: (_, _, _) => _missing(h ?? 120));
    } else {
      image = _missing(h ?? 120);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height.isFinite ? height : null,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(onTap: onTap, child: image),
            if (onSave != null)
              Positioned(
                right: 6,
                bottom: 6,
                child: Pressable(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xcc4a2c0a), borderRadius: BorderRadius.circular(999)),
                    child: const Icon(Icons.download_rounded, color: goldLight, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _missing(double height) => Container(height: height, color: creamDark, alignment: Alignment.center, child: const Icon(Icons.menu_book, color: maroon));

Future<void> shareHash(String title, String hash) {
  final url = "$site/#$hash";
  return SharePlus.instance.share(ShareParams(text: "$title\n$url", subject: title));
}

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ScrollRail extends StatefulWidget {
  final ScrollController controller;
  const ScrollRail({super.key, required this.controller});

  @override
  State<ScrollRail> createState() => _ScrollRailState();
}

class _ScrollRailState extends State<ScrollRail> {
  double opacity = 0;
  Timer? hide;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(onScroll);
  }

  @override
  void didUpdateWidget(ScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(onScroll);
      widget.controller.addListener(onScroll);
    }
  }

  void onScroll() {
    if (!mounted) return;
    hide?.cancel();
    if (opacity != 1) setState(() => opacity = 1);
    hide = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => opacity = 0);
    });
  }

  @override
  void dispose() {
    hide?.cancel();
    widget.controller.removeListener(onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 180),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 4,
            margin: const EdgeInsets.only(right: 3, top: 8, bottom: 8),
            decoration: BoxDecoration(color: const Color(0x887b1f2e), borderRadius: BorderRadius.circular(99)),
          ),
        ),
      ),
    );
  }
}

String hindiWhen(int? stamp) {
  if (stamp == null || stamp == 0) return "";
  final date = DateTime.fromMillisecondsSinceEpoch(stamp);
  const months = ["जन", "फ़र", "मार्च", "अप्रै", "मई", "जून", "जुल", "अग", "सित", "अक्टू", "नव", "दिस"];
  final hh = date.hour.toString().padLeft(2, "0");
  final mm = date.minute.toString().padLeft(2, "0");
  return "${date.day} ${months[date.month - 1]} $hh:$mm";
}
