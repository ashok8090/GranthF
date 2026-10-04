final _safePath = RegExp(r"^(granths|uploads)/[A-Za-z0-9_.-]+$");

const origin = "https://granth.wnmsolutions.com";

String? mediaPath(String? input) {
  if (input == null) return null;
  var path = input.trim();
  if (path.isEmpty) return null;
  if (path.startsWith("http://") || path.startsWith("https://")) {
    path = Uri.tryParse(path)?.path ?? "";
  }
  path = path.replaceFirst(RegExp(r"^/+"), "");
  return _safePath.hasMatch(path) ? path : null;
}

String mediaUrl(String path) => "$origin/$path";

String? youtubeId(String? raw) {
  final value = (raw ?? "").trim();
  if (value.isEmpty) return null;
  if (RegExp(r"^[\w-]{11}$").hasMatch(value)) return value;
  final embedded = RegExp(r"(?:embed/|v=|youtu\.be/)([\w-]{11})").firstMatch(value);
  return embedded?.group(1);
}

int byPosition(String value) => int.tryParse(value) ?? 0;
