import "dart:io";

import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";

class FilesBridge {
  static const _channel = MethodChannel("com.wnm.granthf/files");

  static Future<bool> publish(String path, String name, {required bool pictures, required String mime}) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>("publish", {
        "path": path,
        "name": name,
        "mime": mime,
        "pictures": pictures,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> open(String path, String mime) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod("open", {"path": path, "mime": mime});
        return;
      } catch (_) {}
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: mime)]));
  }
}
