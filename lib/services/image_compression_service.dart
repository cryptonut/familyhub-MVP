import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/services/logger_service.dart';

class ImageCompressionService {
  /// Compress an image file
  Future<File> compressImage(
    File image, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final compressedBytes = await compressImageBytes(
        bytes,
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      // Write to temp file
      final tempFile = File('${image.path}_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e, st) {
      Logger.error('Error compressing image', error: e, stackTrace: st, tag: 'ImageCompressionService');
      rethrow;
    }
  }

  /// Compress image bytes
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize if needed
      img.Image resized = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resized = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
          maintainAspect: true,
        );
      }

      // Encode as JPEG with quality
      final compressed = img.encodeJpg(resized, quality: quality);
      return Uint8List.fromList(compressed);
    } catch (e, st) {
      Logger.error('Error compressing image bytes', error: e, stackTrace: st, tag: 'ImageCompressionService');
      rethrow;
    }
  }

  /// Create thumbnail
  Future<Uint8List> createThumbnail(
    Uint8List bytes, {
    int size = 200,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final thumbnail = img.copyResize(
        image,
        width: size,
        height: size,
        maintainAspect: true,
      );

      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);
      return Uint8List.fromList(thumbnailBytes);
    } catch (e, st) {
      Logger.error('Error creating thumbnail', error: e, stackTrace: st, tag: 'ImageCompressionService');
      rethrow;
    }
  }

  /// Create medium size image
  Future<Uint8List> createMedium(
    Uint8List bytes, {
    int size = 800,
  }) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final medium = img.copyResize(
        image,
        width: image.width > size ? size : null,
        height: image.height > size ? size : null,
        maintainAspect: true,
      );

      final mediumBytes = img.encodeJpg(medium, quality: 85);
      return Uint8List.fromList(mediumBytes);
    } catch (e, st) {
      Logger.error('Error creating medium image', error: e, stackTrace: st, tag: 'ImageCompressionService');
      rethrow;
    }
  }
}

