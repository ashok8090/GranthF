class Dest {
  final String panel;
  final String? topicId;
  final String? granthId;
  final String? pramanId;
  const Dest(this.panel, {this.topicId, this.granthId, this.pramanId});

  static const dashboard = Dest("dashboard");
  static const topics = Dest("topics");
  static const granths = Dest("granths");
  static const pramans = Dest("pramans");
  static const gallery = Dest("gallery");

  String get key => "$panel|${topicId ?? ""}|${granthId ?? ""}|${pramanId ?? ""}";

  bool same(Dest other) => key == other.key;
}

Dest? destFromUri(Uri uri) {
  Uri parsed;
  if (uri.fragment.isNotEmpty) {
    final fragment = uri.fragment;
    parsed = Uri.parse("https://granth.local/${fragment.startsWith("/") ? fragment.substring(1) : fragment}");
  } else if (uri.scheme == "granth" && uri.host.isNotEmpty && uri.host != "pramans" && uri.host != "topics" && uri.host != "granths" && uri.host != "gallery") {
    final path = uri.path.isEmpty ? "/" : uri.path;
    parsed = Uri.parse("https://granth.local$path${uri.hasQuery ? "?${uri.query}" : ""}");
  } else if (uri.scheme == "granth" && uri.host.isNotEmpty && (uri.path.isEmpty || uri.path == "/")) {
    parsed = Uri.parse("https://granth.local/${uri.host}${uri.hasQuery ? "?${uri.query}" : ""}");
  } else {
    parsed = uri;
  }
  final path = parsed.path;
  final params = parsed.queryParameters;
  final granth = params["granth"];
  final topic = params["topic"];
  final id = params["id"];
  if (path.contains("gallery")) return Dest.gallery;
  if (path.contains("topic") && !path.contains("praman") && topic == null && granth == null && id == null) return Dest.topics;
  if (path.contains("granth") && !path.contains("praman") && topic == null && granth == null && id == null) return Dest.granths;
  if (path.contains("praman") || granth != null || topic != null || id != null) {
    return Dest("pramans", topicId: topic, granthId: granth, pramanId: id);
  }
  if (uri.scheme == "granth" || uri.host == "granth.grok.me" || parsed.host == "granth.grok.me") return Dest.dashboard;
  return null;
}
