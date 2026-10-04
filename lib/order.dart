import "models.dart";

const _digits = "०१२३४५६७८९";
const _missing = 1000000000;
final _tail = RegExp(r"(?:\s*(?:नं\.?|नंबर|संख्या|number))?\s*[:\-–]?\s*(\d+)");

final _fields = <RegExp>[
  RegExp("भाग${_tail.pattern}"),
  RegExp("ख(?:ण्ड|ंड)${_tail.pattern}"),
  RegExp("स्क(?:न्ध|ंध)${_tail.pattern}"),
  RegExp("(?:मण्डल|मंडल)${_tail.pattern}"),
  RegExp("अध्याय${_tail.pattern}"),
  RegExp("सूक्त${_tail.pattern}"),
  RegExp("श्लोक${_tail.pattern}"),
  RegExp("(?:मंत्र|मन्त्र)${_tail.pattern}"),
  RegExp("(?:पेज|पृष्ठ|page)${_tail.pattern}", caseSensitive: false),
];

const _pageIndex = 8;

const kabirChapters = [
  "ज्ञानसागर",
  "अनुरागसागर",
  "अम्बुसागर",
  "विवेकसागर",
  "सर्वज्ञसागर",
  "ज्ञानप्रकाश",
  "अमरसिंह बोध",
  "बीरसिंह बोध",
  "भोपाल बोध",
  "जगजीवन बोध",
  "गरुड़ बोध",
  "हनुमान बोध",
  "लक्ष्मण बोध",
  "मोहम्मद बोध",
  "काफिर बोध",
  "सुल्तान बोध",
  "निरंजन बोध",
  "ज्ञानबोध",
  "भवतारण बोध",
  "मुक्तिबोध",
  "चौकास्वरोदय",
  "अलिफनामा",
  "कबीरबानी",
  "कर्मबोध",
  "अमरमूल",
  "उग्रगीता",
  "ज्ञानस्थिति बोध",
  "संतोष बोध",
  "कायापांजी",
  "पंचमुद्रा",
  "आत्मबोध",
  "जैनधर्म बोध",
  "स्वसमवेद बोध",
  "धर्मबोध",
  "कमाल बोध",
  "स्वाश गुंजार",
  "अगमनिगम बोध",
  "सुमिरन बोध",
  "कबीरचरित्र बोध",
  "गुरु महात्म्य",
  "जीवधर्म बोध",
];

String devanagariDigits(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = _digits.indexOf(char);
    buffer.write(index >= 0 ? "$index" : char);
  }
  return buffer.toString();
}

bool isKabirSagar(String title) => RegExp(r"कबीर\s*सागर|kabir\s*sagar", caseSensitive: false).hasMatch(title);

List<int> pramanOrderKey(String title) {
  final text = devanagariDigits(title);
  final keys = _fields.map((pattern) {
    final match = pattern.firstMatch(text);
    return match == null ? _missing : int.tryParse(match.group(1) ?? "") ?? _missing;
  }).toList();
  if (keys.every((value) => value == _missing)) {
    final any = RegExp(r"(\d+)").firstMatch(text);
    keys.add(any == null ? _missing : int.parse(any.group(1)!));
  }
  return keys;
}

class _KabirRank {
  final int order;
  final int page;
  const _KabirRank(this.order, this.page);
}

_KabirRank _kabirRank(String title) {
  final spaced = devanagariDigits(title).replaceAll("़", "");
  final compact = spaced.replaceAll(RegExp(r"\s+"), "");
  var order = kabirChapters.length + 5;
  final ranked = [...kabirChapters]..sort((a, b) => b.length.compareTo(a.length));
  for (final name in ranked) {
    final key = name.replaceAll(RegExp(r"\s+"), "");
    if (spaced.contains(name) || compact.contains(key)) {
      order = kabirChapters.indexOf(name);
      break;
    }
  }
  final pageMatch = RegExp(r"(?:पेज|पृष्ठ|page)\s*(?:नं\.?|नंबर|संख्या|number)?\s*[:\-–]?\s*(\d+)", caseSensitive: false).firstMatch(spaced);
  final loose = pageMatch != null ? int.parse(pageMatch.group(1)!) : int.tryParse(RegExp(r"(\d+)").firstMatch(spaced)?.group(1) ?? "") ?? _missing;
  return _KabirRank(order, loose);
}

int _compareKeys(List<int> left, List<int> right, List<int> order) {
  for (final index in order) {
    final delta = (index < left.length ? left[index] : _missing) - (index < right.length ? right[index] : _missing);
    if (delta != 0) return delta;
  }
  final leftTail = left.length > _fields.length ? left[_fields.length] : _missing;
  final rightTail = right.length > _fields.length ? right[_fields.length] : _missing;
  return leftTail - rightTail;
}

List<Praman> sortPramans(List<Praman> rows, [String granthTitle = ""]) {
  final groups = <String, List<Praman>>{};
  for (final row in rows) {
    final key = "${row.granthId}|${granthTitle.isNotEmpty ? granthTitle : row.granthTitle}";
    groups.putIfAbsent(key, () => []).add(row);
  }
  List<Praman> sortGroup(List<Praman> list, String title) {
    if (isKabirSagar(title)) {
      final copy = [...list];
      copy.sort((a, b) {
        final left = _kabirRank(a.title);
        final right = _kabirRank(b.title);
        if (left.order != right.order) return left.order.compareTo(right.order);
        if (left.page != right.page) return left.page.compareTo(right.page);
        return a.id.compareTo(b.id);
      });
      return copy;
    }
    const pageFirst = [_pageIndex, 4, 6, 7, 0, 1, 5, 2, 3];
    final copy = [...list];
    copy.sort((a, b) {
      final delta = _compareKeys(pramanOrderKey(a.title), pramanOrderKey(b.title), pageFirst);
      if (delta != 0) return delta;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  if (groups.length <= 1) return sortGroup(rows, granthTitle.isNotEmpty ? granthTitle : (rows.isEmpty ? "" : rows.first.granthTitle));
  final keys = groups.keys.toList()..sort();
  return [for (final key in keys) ...sortGroup(groups[key]!, key.split("|").skip(1).join("|"))];
}
