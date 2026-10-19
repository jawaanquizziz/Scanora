import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/scan_page.dart';
import 'file_service.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  /// Process an image with crop, rotation, and filter, saving to a new temp file
  Future<String> processPage(ScanPage page) async {
    return compute(_processPageIsolate, page);
  }

  /// Fast preview generation for UI filter picker
  Future<Uint8List> generateFilterPreview(String imagePath, FilterType filter) async {
    return compute(_filterPreviewIsolate, _FilterPreviewParams(imagePath, filter));
  }

  /// Create a compact thumbnail for documents list
  Future<String> createThumbnail(String sourceImagePath, String docId) async {
    return compute(_thumbnailIsolate, _ThumbnailParams(sourceImagePath, docId));
  }
}

class _FilterPreviewParams {
  final String imagePath;
  final FilterType filter;
  _FilterPreviewParams(this.imagePath, this.filter);
}

class _ThumbnailParams {
  final String sourceImagePath;
  final String docId;
  _ThumbnailParams(this.sourceImagePath, this.docId);
}

Future<String> _processPageIsolate(ScanPage page) async {
  final file = File(page.originalImagePath);
  if (!await file.exists()) {
    throw Exception('Original image file not found: ${page.originalImagePath}');
  }

  final bytes = await file.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // 1. Apply Rotation
  if (page.rotationAngle != 0) {
    image = img.copyRotate(image, angle: page.rotationAngle.toDouble());
  }

  // 2. Apply Crop if bounds are non-default
  final hasCrop = page.cropLeft > 0.005 ||
      page.cropTop > 0.005 ||
      page.cropRight < 0.995 ||
      page.cropBottom < 0.995;

  if (hasCrop) {
    final x = (page.cropLeft.clamp(0.0, 1.0) * image.width).round();
    final y = (page.cropTop.clamp(0.0, 1.0) * image.height).round();
    final width = ((page.cropRight.clamp(0.0, 1.0) - page.cropLeft.clamp(0.0, 1.0)) * image.width).round();
    final height = ((page.cropBottom.clamp(0.0, 1.0) - page.cropTop.clamp(0.0, 1.0)) * image.height).round();

    if (width > 10 && height > 10) {
      image = img.copyCrop(
        image,
        x: x.clamp(0, image.width - 1),
        y: y.clamp(0, image.height - 1),
        width: width.clamp(1, image.width - x),
        height: height.clamp(1, image.height - y),
      );
    }
  }

  // 3. Apply Filter
  image = _applyFilter(image, page.filter);

  // 4. Save to temp file
  final fileService = FileService();
  final outPath = await fileService.createTempImagePath('jpg');
  final encodedBytes = img.encodeJpg(image, quality: 88);
  await File(outPath).writeAsBytes(encodedBytes);
  return outPath;
}

img.Image _applyFilter(img.Image input, FilterType filter) {
  switch (filter) {
    case FilterType.original:
      return input;
    case FilterType.enhance:
      // Boost contrast and brightness for document readability
      final enhanced = img.adjustColor(
        input,
        contrast: 1.25,
        brightness: 1.08,
        saturation: 1.1,
      );
      return enhanced;
    case FilterType.grayscale:
      return img.grayscale(input);
    case FilterType.blackAndWhite:
      final gray = img.grayscale(input);
      // High contrast document threshold
      return img.luminanceThreshold(gray, threshold: 0.55);
  }
}

Future<Uint8List> _filterPreviewIsolate(_FilterPreviewParams params) async {
  final file = File(params.imagePath);
  final bytes = await file.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  // Scale down for fast preview rendering
  if (image.width > 300) {
    image = img.copyResize(image, width: 300);
  }

  image = _applyFilter(image, params.filter);
  return Uint8List.fromList(img.encodeJpg(image, quality: 75));
}

Future<String> _thumbnailIsolate(_ThumbnailParams params) async {
  final file = File(params.sourceImagePath);
  final bytes = await file.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) throw Exception('Cannot decode thumbnail image');

  final thumb = img.copyResize(image, width: 320);
  final fileService = FileService();
  final thumbPath = await fileService.createThumbnailPath(params.docId);
  await File(thumbPath).writeAsBytes(img.encodeJpg(thumb, quality: 80));
  return thumbPath;
}
