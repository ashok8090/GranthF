import "package:flutter_test/flutter_test.dart";
import "package:granth_f/models.dart";
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
}
