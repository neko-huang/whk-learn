import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// 图片服务 - 处理拍照、相册选择和图片存储
class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// 从相机拍照获取图片
  static Future<String?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 压缩质量，减少存储占用
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) return null;

      return await _saveImageToLocal(File(photo.path));
    } catch (e) {
      debugPrint('拍照失败: $e');
      return null;
    }
  }

  /// 从相册选择图片
  static Future<String?> pickFromGallery() async {
    try {
      // 请求权限
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          debugPrint('相册权限被拒绝');
          return null;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return null;

      return await _saveImageToLocal(File(image.path));
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return null;
    }
  }

  /// 多张图片从相册选择
  static Future<List<String>> pickMultipleFromGallery() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          debugPrint('相册权限被拒绝');
          return [];
        }
      }

      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      final paths = <String>[];
      for (final image in images) {
        final savedPath = await _saveImageToLocal(File(image.path));
        if (savedPath != null) {
          paths.add(savedPath);
        }
      }

      return paths;
    } catch (e) {
      debugPrint('多选图片失败: $e');
      return [];
    }
  }

  /// 保存图片到应用本地存储目录
  static Future<String?> _saveImageToLocal(File imageFile) async {
    try {
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'mistake_images'));
      
      // 确保目录存在
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(imageFile.path);
      final fileName = 'mistake_$timestamp$extension';
      final targetPath = p.join(imagesDir.path, fileName);

      // 复制文件到目标路径
      await imageFile.copy(targetPath);

      // 删除临时文件（如果是从相册获取的）
      if (imageFile.path != targetPath) {
        try {
          await imageFile.delete();
        } catch (e) {
          // 临时文件删除失败不影响主流程
        }
      }

      return targetPath;
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return null;
    }
  }

  /// 删除图片文件
  static Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('删除图片失败: $e');
      return false;
    }
  }

  /// 检查图片文件是否存在
  static Future<bool> imageExists(String imagePath) async {
    try {
      return await File(imagePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取图片文件大小（字节）
  static Future<int?> getImageSize(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 清理孤立的图片文件（不在数据库中的）
  static Future<void> cleanupOrphanImages(Set<String> usedImagePaths) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'mistake_images'));
      
      if (!await imagesDir.exists()) return;

      await for (final entity in imagesDir.list()) {
        if (entity is File && !usedImagePaths.contains(entity.path)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('清理孤立图片失败: $e');
    }
  }
}
