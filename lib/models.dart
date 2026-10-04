class Topic {
  final String id;
  final String title;
  final String description;
  final String position;
  final String granthCount;
  final String pramanCount;

  const Topic({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.granthCount,
    required this.pramanCount,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: _s(json["id"]),
        title: _s(json["title"]),
        description: _s(json["description"]),
        position: _s(json["position"]),
        granthCount: _s(json["granth_count"]),
        pramanCount: _s(json["praman_count"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "description": description,
        "position": position,
        "granth_count": granthCount,
        "praman_count": pramanCount,
      };
}

class Granth {
  final String id;
  final String title;
  final String author;
  final String description;
  final String imagePath;
  final String editorImagePath;
  final String granthUrl;
  final String position;
  final String pramanCount;

  const Granth({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.imagePath,
    required this.editorImagePath,
    required this.granthUrl,
    required this.position,
    required this.pramanCount,
  });

  factory Granth.fromJson(Map<String, dynamic> json) => Granth(
        id: _s(json["id"]),
        title: _s(json["title"]),
        author: _s(json["author"]),
        description: _s(json["description"]),
        imagePath: _s(json["imagePath"]),
        editorImagePath: _s(json["editorImagePath"]),
        granthUrl: _s(json["granthURL"]),
        position: _s(json["position"]),
        pramanCount: _s(json["pramanCount"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "author": author,
        "description": description,
        "imagePath": imagePath,
        "editorImagePath": editorImagePath,
        "granthURL": granthUrl,
        "position": position,
        "pramanCount": pramanCount,
      };
}

class Praman {
  final String id;
  final String title;
  final String description;
  final String favorite;
  final String topicId;
  final String granthId;
  final String imagePath;
  final String youtubeUrl;
  final String youtubeStart;
  final String youtubeDesc;
  final String topicTitle;
  final String granthTitle;
  final String granthImage;
  final String editorImagePath;
  final String granthAuthor;

  const Praman({
    required this.id,
    required this.title,
    required this.description,
    required this.favorite,
    required this.topicId,
    required this.granthId,
    required this.imagePath,
    required this.youtubeUrl,
    required this.youtubeStart,
    required this.youtubeDesc,
    required this.topicTitle,
    required this.granthTitle,
    required this.granthImage,
    required this.editorImagePath,
    required this.granthAuthor,
  });

  factory Praman.fromJson(Map<String, dynamic> json) => Praman(
        id: _s(json["id"]),
        title: _s(json["title"]),
        description: _s(json["description"]),
        favorite: _s(json["is_favorate"]),
        topicId: _s(json["topic_id"]),
        granthId: _s(json["granth_id"]),
        imagePath: _s(json["image_path"]),
        youtubeUrl: _s(json["youtube_url"]),
        youtubeStart: _s(json["youtube_start"]),
        youtubeDesc: _s(json["youtube_desc"]),
        topicTitle: _s(json["topic_title"]),
        granthTitle: _s(json["granth_title"]),
        granthImage: _s(json["granth_image"]),
        editorImagePath: _s(json["editorImagePath"]),
        granthAuthor: _s(json["granth_auther"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "description": description,
        "is_favorate": favorite,
        "topic_id": topicId,
        "granth_id": granthId,
        "image_path": imagePath,
        "youtube_url": youtubeUrl,
        "youtube_start": youtubeStart,
        "youtube_desc": youtubeDesc,
        "topic_title": topicTitle,
        "granth_title": granthTitle,
        "granth_image": granthImage,
        "editorImagePath": editorImagePath,
        "granth_auther": granthAuthor,
      };
}

class GalleryItem {
  final String id;
  final String kind;
  final String title;
  final String text;
  final String topic;
  final String granth;
  final String folderId;
  final int createdAt;
  final int size;
  final String fileName;
  final String filePath;
  final String previewPath;

  const GalleryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    required this.topic,
    required this.granth,
    required this.folderId,
    required this.createdAt,
    required this.size,
    required this.fileName,
    required this.filePath,
    required this.previewPath,
  });
}

String _s(Object? value) => value == null ? "" : "$value".trim();
