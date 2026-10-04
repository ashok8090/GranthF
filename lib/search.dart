final _matras = RegExp(r"[\u093e\u093f\u0940\u0941\u0942\u0943\u0944\u0947\u0948\u094b\u094c\u0902\u0901\u094d\u093c\u200c\u200d]");

const clusters = <List<String>>[
  ["मांस", "माँस", "mans", "maans", "maas", "meat"],
  ["मृत्यु", "मरण", "मौत", "mrityu", "mrutyu", "maran", "maut", "death"],
  ["ब्रह्मा", "ब्रह्म", "brahma", "brahm", "bramha"],
  ["कृष्ण", "krishna", "krishan", "kishan"],
  ["कबीर", "kabir", "kabeer", "kavir"],
  ["गीता", "gita", "geeta", "githa"],
  ["भगवद्गीता", "भगवदगीता", "bhagavad", "bhagwat", "bhagwad"],
  ["गुरु", "गुरू", "सद्गुरु", "सतगुरु", "guru", "sadguru", "satguru"],
  ["मोक्ष", "मुक्ति", "moksha", "mukti"],
  ["राम", "raam", "ram", "rama"],
  ["रामायण", "ramayan", "ramayana"],
  ["शिव", "shiv", "shiva"],
  ["वेद", "veda", "ved"],
  ["हनुमान", "hanuman"],
  ["कर्म", "karma", "karm"],
  ["धर्म", "dharma", "dharm"],
  ["आत्मा", "atma"],
  ["भक्ति", "bhakti"],
  ["ज्ञान", "gyan", "gyaan", "jnana"],
  ["संत", "सन्त", "sant"],
];

String normalizeText(String value) {
  final lower = value.toLowerCase();
  final cleaned = lower.replaceAll(RegExp(r"[^\p{L}\p{M}\p{N}\s]", unicode: true), " ");
  return cleaned.replaceAll(RegExp(r"\s+"), " ").trim();
}

String stripMatras(String value) => normalizeText(value).replaceAll(_matras, "");

class Prepared {
  final String text;
  final String bare;
  const Prepared(this.text, this.bare);
}

Prepared prepare(Iterable<String> fields) {
  final joined = fields.where((field) => field.trim().isNotEmpty).join(" ");
  final text = normalizeText(joined);
  return Prepared(text, text.replaceAll(_matras, ""));
}

List<String> needlesFor(String query) {
  final text = normalizeText(query);
  if (text.isEmpty) return const [];
  final bare = text.replaceAll(_matras, "");
  final out = <String>{text, bare};
  if (text.length >= 2) {
    for (final cluster in clusters) {
      final hit = cluster.any((word) {
        final norm = normalizeText(word);
        final stripped = norm.replaceAll(_matras, "");
        if (text.length >= 3 && (norm.contains(text) || stripped.contains(bare))) return true;
        return text.contains(norm) || bare.contains(stripped);
      });
      if (!hit) continue;
      for (final word in cluster) {
        final norm = normalizeText(word);
        out.add(norm);
        out.add(norm.replaceAll(_matras, ""));
      }
    }
  }
  return out.where((item) => item.isNotEmpty).toList();
}

bool matches(Prepared doc, List<String> needles) {
  for (final needle in needles) {
    if (doc.text.contains(needle) || doc.bare.contains(needle)) return true;
  }
  return false;
}

int matchRank(Prepared doc, List<String> needles) {
  var best = 1 << 20;
  for (final needle in needles) {
    final at = doc.text.indexOf(needle);
    final bareAt = doc.bare.indexOf(needle);
    if (at >= 0 && at < best) best = at;
    if (bareAt >= 0 && bareAt < best) best = bareAt;
  }
  return best;
}
