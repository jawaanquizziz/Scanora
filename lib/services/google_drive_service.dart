import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../models/scanned_document.dart';
import 'storage_service.dart';

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const String kDriveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const String kDriveFolderName = 'Scanora Documents';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      kDriveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isSigningIn = false;
  bool _isBatchSyncing = false;
  final Set<String> _syncingDocIds = <String>{};
  String? _cachedFolderId;
  String? _lastError;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userDisplayName => _currentUser?.displayName;
  bool get isSigningIn => _isSigningIn;
  bool get isBatchSyncing => _isBatchSyncing;
  bool get isSyncing => _isBatchSyncing || _syncingDocIds.isNotEmpty;
  String? get lastError => _lastError;

  bool isDocSyncing(String docId) => _syncingDocIds.contains(docId);

  Future<void> init() async {
    try {
      _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
        _currentUser = account;
        if (account == null) {
          _cachedFolderId = null;
        }
        notifyListeners();
      });
      _currentUser = await _googleSignIn.signInSilently();
      notifyListeners();
    } catch (e) {
      debugPrint('GoogleDriveService silent sign-in skipped: $e');
    }
  }

  Future<bool> signIn() async {
    _isSigningIn = true;
    _lastError = null;
    notifyListeners();

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      final account = await _googleSignIn.signIn();
      _currentUser = account;

      if (account != null) {
        try {
          await _googleSignIn.requestScopes(<String>[kDriveFileScope]);
        } catch (e) {
          debugPrint('Scope request warning: $e');
        }
      }

      _isSigningIn = false;
      notifyListeners();

      if (account != null) {
        if (StorageService().settings.autoSyncToDrive) {
          syncAllPendingDocuments();
        }
        return true;
      }
      return false;
    } catch (e) {
      _isSigningIn = false;
      _lastError = _formatSignInError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _currentUser = null;
    _cachedFolderId = null;
    _lastError = null;
    notifyListeners();
  }

  String _formatSignInError(Object e) {
    final msg = e.toString();
    if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
      return 'Google Sign-In OAuth client is not configured for this build SHA-1 yet. Register package "com.scanora.app.scanora" with your SHA-1 in Google Cloud Console.';
    }
    if (msg.contains('network_error') || msg.contains('7:')) {
      return 'Network error while connecting to Google Account. Check your internet connection.';
    }
    return 'Could not complete Google Sign-In.';
  }

  Future<String?> _getOrCreateScanoraFolder(Map<String, String> authHeaders) async {
    if (_cachedFolderId != null && _cachedFolderId!.isNotEmpty) {
      return _cachedFolderId;
    }

    final query = Uri.encodeQueryComponent(
      "name = '$kDriveFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
    );
    final searchUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=$query&spaces=drive&fields=files(id,name)',
    );

    final searchRes = await http.get(searchUri, headers: authHeaders);
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>? ?? [];
      if (files.isNotEmpty) {
        final first = files.first as Map<String, dynamic>;
        _cachedFolderId = first['id'] as String?;
        return _cachedFolderId;
      }
    }

    // Create the folder if not found
    final createUri = Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id');
    final createRes = await http.post(
      createUri,
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'name': kDriveFolderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );

    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final data = jsonDecode(createRes.body) as Map<String, dynamic>;
      _cachedFolderId = data['id'] as String?;
      return _cachedFolderId;
    }

    return null;
  }

  Future<String?> uploadDocument(ScannedDocument doc) async {
    if (_currentUser == null) {
      _lastError = 'Please sign in with Google first to save to Google Drive.';
      notifyListeners();
      return null;
    }

    if (_syncingDocIds.contains(doc.id)) return doc.driveFileId;

    final file = File(doc.filePath);
    if (!await file.exists()) {
      _lastError = 'Local PDF file not found on device.';
      notifyListeners();
      return null;
    }

    _syncingDocIds.add(doc.id);
    _lastError = null;
    notifyListeners();

    try {
      final fileBytes = await file.readAsBytes();
      final fileName = doc.title.toLowerCase().endsWith('.pdf')
          ? doc.title
          : '${doc.title}.pdf';

      Map<String, String> authHeaders = await _currentUser!.authHeaders;
      String? folderId = await _getOrCreateScanoraFolder(authHeaders);

      // If folder creation returned null (e.g. scope not granted yet), request Drive scope and retry once
      if (folderId == null) {
        final granted = await _googleSignIn.requestScopes(<String>[kDriveFileScope]);
        if (granted) {
          authHeaders = await _currentUser!.authHeaders;
          folderId = await _getOrCreateScanoraFolder(authHeaders);
        }
      }

      final bool isUpdate = doc.driveFileId != null &&
          doc.driveFileId!.isNotEmpty &&
          !doc.driveFileId!.startsWith('cloud_backup_');
      final metadata = <String, dynamic>{
        'name': fileName,
        'mimeType': 'application/pdf',
        if (!isUpdate && folderId != null) 'parents': [folderId],
      };

      const boundary = 'scanora_drive_multipart_boundary';
      final metadataJson = jsonEncode(metadata);

      final bodyBytes = BytesBuilder();
      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
      bodyBytes.add(utf8.encode('$metadataJson\r\n'));
      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/pdf\r\n\r\n'));
      bodyBytes.add(fileBytes);
      bodyBytes.add(utf8.encode('\r\n--$boundary--\r\n'));

      final Uri uploadUri = isUpdate
          ? Uri.parse(
              'https://www.googleapis.com/upload/drive/v3/files/${doc.driveFileId}?uploadType=multipart&fields=id,name,modifiedTime',
            )
          : Uri.parse(
              'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,modifiedTime',
            );

      final headers = {
        ...authHeaders,
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Content-Length': bodyBytes.length.toString(),
      };

      final http.Response response = isUpdate
          ? await http.patch(uploadUri, headers: headers, body: bodyBytes.toBytes())
          : await http.post(uploadUri, headers: headers, body: bodyBytes.toBytes());

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final driveId = data['id'] as String?;
        if (driveId != null && driveId.isNotEmpty) {
          final latestDoc = StorageService().getDocument(doc.id) ?? doc;
          final updated = latestDoc.copyWith(
            driveFileId: driveId,
            syncedAt: DateTime.now(),
          );
          await StorageService().updateDocument(updated);
          _syncingDocIds.remove(doc.id);
          notifyListeners();
          return driveId;
        }
      } else if (isUpdate && response.statusCode == 404) {
        final clearedDoc = doc.copyWith(clearDriveSync: true);
        _syncingDocIds.remove(doc.id);
        return await uploadDocument(clearedDoc);
      } else {
        String apiMessage = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          final errObj = errJson['error'];
          if (errObj is Map<String, dynamic> && errObj['message'] != null) {
            apiMessage = errObj['message'].toString();
          }
        } catch (_) {}
        if (apiMessage.contains('accessNotConfigured') ||
            apiMessage.contains('has not been used in project') ||
            apiMessage.contains('is disabled')) {
          _lastError =
              'Enable Google Drive API in Google Cloud Console for project "scanora-j27" (1054850397639), then tap Sync again.';
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          _lastError =
              'Google Drive permission or API not enabled ($apiMessage). Make sure Google Drive API is enabled for project "scanora-j27".';
        } else {
          _lastError = 'Google Drive upload failed: $apiMessage';
        }
      }
    } catch (e) {
      _lastError = 'Cloud sync error: $e';
    }

    _syncingDocIds.remove(doc.id);
    notifyListeners();
    return null;
  }

  Future<int> syncAllPendingDocuments() async {
    if (_currentUser == null || _isBatchSyncing) return 0;
    _isBatchSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      final docs = List<ScannedDocument>.from(StorageService().documents);
      for (final doc in docs) {
        final needsSync = !doc.isCloudSynced ||
            doc.syncedAt == null ||
            doc.modifiedAt.isAfter(doc.syncedAt!);
        if (needsSync) {
          final id = await uploadDocument(doc);
          if (id != null) syncedCount++;
        }
      }
    } finally {
      _isBatchSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  Future<int> syncAllUnsyncedDocuments() => syncAllPendingDocuments();
}
