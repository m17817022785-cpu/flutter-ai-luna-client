import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageSaveService {
  /// Downloads a network image and saves it to an app-accessible directory.
  ///
  /// The previous implementation used the `gal` plugin to insert the image into
  /// the system gallery. That plugin currently fails during Android Gradle
  /// configuration in CI (`Could not get unknown property 'flutter'`), which
  /// prevents APK generation. This implementation keeps the feature functional
  /// without a fragile native plugin by saving the file under a stable
  /// app-managed folder.
  static Future<File> saveNetworkImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('图片下载失败，状态码: ${response.statusCode}');
    }

    final Directory baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final saveDir = Directory('${baseDir.path}/luna_images');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final file = File('${saveDir.path}/luna_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}
