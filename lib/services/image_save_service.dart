import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageSaveService {
  /// 下载网络图片并将其保存至手机系统相册中 (兼容 Android 10+ / iOS)
  static Future<void> saveNetworkImage(String url) async {
    // 1. 请求相册写入权限
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      throw Exception('未授予相册存储访问权限');
    }

    // 2. 发起 HTTP GET 请求下载图片字节
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('图片下载失败，HTTP状态码: ${response.statusCode}');
    }

    // 3. 将字节数据写入临时文件
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ai_gen_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(response.bodyBytes);

    // 4. 调用 gal 插件将 file.path 保存至系统相册
    try {
      await Gal.putImage(file.path);
    } finally {
      // 无论成功还是失败，均安全删除本地临时缓存文件
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}