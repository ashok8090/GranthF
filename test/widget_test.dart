import "package:flutter_test/flutter_test.dart";
import "package:granth_f/models.dart";
import "package:granth_f/nav.dart";
import "package:granth_f/order.dart";

Praman row(String id, String title) => Praman(
      id: id,
      title: title,
      description: "",
      favorite: "0",
      topicId: "1",
      granthId: "7",
      imagePath: "",
      youtubeUrl: "",
      youtubeStart: "0",
      youtubeDesc: "",
      topicTitle: "",
      granthTitle: "कबीर सागर",
      granthImage: "",
      editorImagePath: "",
      granthAuthor: "",
    );

void main() {
  test("kabir chapters stay in the scripture order", () {
    final sorted = sortPramans([
      row("2", "कबीर सागर जीवधर्म बोध पेज 2"),
      row("1", "कबीर सागर ज्ञानसागर पेज 10"),
    ], "कबीर सागर");
    expect(sorted.first.id, "1");
    expect(sorted.last.id, "2");
  });

  test("share links open the matching page", () {
    final proof = destFromUri(Uri.parse("https://granth.grok.me/pramans?id=42"));
    expect(proof?.panel, "pramans");
    expect(proof?.pramanId, "42");

    final topic = destFromUri(Uri.parse("https://granth.grok.me/#/pramans?topic=t1"));
    expect(topic?.topicId, "t1");

    final book = destFromUri(Uri.parse("granth://open/pramans?granth=g7"));
    expect(book?.granthId, "g7");
    expect(book?.panel, "pramans");

    expect(destFromUri(Uri.parse("https://granth.grok.me/gallery"))?.panel, "gallery");
    expect(destFromUri(Uri.parse("granth://open"))?.panel, "dashboard");
  });
}
