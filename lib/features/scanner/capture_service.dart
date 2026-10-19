import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/scan_page.dart';
import '../../services/file_service.dart';

class CaptureService {
  static final ImagePicker _picker = ImagePicker();

  /// Captures a single image from the device camera, falling back to gallery if camera is unavailable
  static Future<ScanPage?> captureFromCamera(BuildContext context) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (photo == null) return null;

      final fileService = FileService();
      final tempPath = await fileService.createTempImagePath('jpg');
      await File(photo.path).copy(tempPath);

      final id = 'page_${DateTime.now().millisecondsSinceEpoch}';
      return ScanPage(
        id: id,
        originalImagePath: tempPath,
        processedImagePath: tempPath,
      );
    } catch (_) {
      // Graceful fallback for devices or desktop platforms without active camera hardware
      try {
        final XFile? galleryPhoto = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
        );

        if (galleryPhoto == null) return null;

        final fileService = FileService();
        final tempPath = await fileService.createTempImagePath('jpg');
        await File(galleryPhoto.path).copy(tempPath);

        final id = 'page_${DateTime.now().millisecondsSinceEpoch}';
        return ScanPage(
          id: id,
          originalImagePath: tempPath,
          processedImagePath: tempPath,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Capture error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
    }
  }

  /// Imports one or more images from device photo gallery
  static Future<List<ScanPage>> importFromGallery(BuildContext context) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 92,
      );

      if (images.isEmpty) return [];

      final fileService = FileService();
      final List<ScanPage> pages = [];

      for (int i = 0; i < images.length; i++) {
        final img = images[i];
        final tempPath = await fileService.createTempImagePath('jpg');
        await File(img.path).copy(tempPath);

        final id = 'page_${DateTime.now().millisecondsSinceEpoch}_$i';
        pages.add(ScanPage(
          id: id,
          originalImagePath: tempPath,
          processedImagePath: tempPath,
        ));
      }

      return pages;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gallery import error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return [];
    }
  }
}
