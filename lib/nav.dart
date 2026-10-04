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
  final fragment = uri.fragment;
  final parsed = fragment.isNotEmpty
      ? Uri.parse("https://granth.local/${fragment.startsWith("/") ? fragment.substring(1) : fragment}")
      : uri;
  final path = parsed.path;
  final params = parsed.queryParameters;
  final granth = params["granth"];
  final topic = params["topic"];
  final id = params["id"];
  if (path.contains("gallery")) return Dest.gallery;
  if (path.contains("topic") && topic == null && granth == null && id == null && !path.contains("praman")) return Dest.topics;
  if (path.contains("granth") && topic == null && granth == null && id == null && !path.contains("praman")) return Dest.granths;
  if (path.contains("praman") || granth != null || topic != null || id != null) {
    return Dest("pramans", topicId: topic, granthId: granth, pramanId: id);
  }
  if (uri.scheme == "granth" || uri.host == "granth.grok.me") return Dest.dashboard;
  return null;
}
