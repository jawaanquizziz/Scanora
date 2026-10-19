import 'package:flutter/material.dart';
import '../../models/scanned_document.dart';
import 'mlkit_scanner_service.dart';

/// Legacy alias kept for backwards compatibility, forwarding to [MlKitScannerService].
class PaperScannerService {
  static Future<ScannedDocument?> startScan({
    required BuildContext context,
    String? customTitle,
    String? folderId,
  }) async {
    return MlKitScannerService.startScan(
      context: context,
      customTitle: customTitle,
      folderId: folderId,
    );
  }
}
