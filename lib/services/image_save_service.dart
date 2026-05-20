import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaveService {
  /// 下载网络图片并保存到系统相册
  static Future<void> saveNetworkImage(String imageUrl) async {
    // 1. 请求相册/存储写入权限
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final request = await Gal.requestAccess();
      if (!request) {
        throw Exception('未获得保存图片到相册的权限，请在设置中开启');
      }
    }

    // 2. 下载图片
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('图片下载失败，状态码: ${response.statusCode}');
    }

    // 3. 写入临时文件
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(response.bodyBytes);

    // 4. 保存到相册
    await Gal.putImage(file.path);

    // 5. 清理临时文件
    if (await file.exists()) {
      await file.delete();
    }
  }
}
