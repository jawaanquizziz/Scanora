import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../core/utils/file_utils.dart';
import '../models/document_folder.dart';
import '../models/scanned_document.dart';
import 'file_service.dart';
import 'pdf_thumbnail_service.dart';
import 'storage_service.dart';

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const String kDriveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const String kDriveFolderName = 'Scanora Documents';
  static const String kDriveManifestName = 'scanora_metadata.json';
  static const String _kFirebaseWebClientId =
      '1054850397639-reebbg8g0n33avcuqdq6vru1ooqf443e.apps.googleusercontent.com';
  static const String _kFirebaseApiKey =
      'AIzaSyB_uwlsO-2A5Zrti9H8oObOndHmRHZnpVY';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _kFirebaseWebClientId,
    scopes: <String>[
      'email',
      kDriveFileScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isSigningIn = false;
  bool _isBatchSyncing = false;
  bool _isRestoring = false;
  final Set<String> _syncingDocIds = <String>{};
  String? _cachedFolderId;
  String? _cachedManifestId;
  String? _lastError;
  int _lastRestoredCount = 0;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get userEmail => _currentUser?.email;
  String? get userDisplayName => _currentUser?.displayName;
  String? get userPhotoUrl => _currentUser?.photoUrl;
  bool get isSigningIn => _isSigningIn;
  bool get isBatchSyncing => _isBatchSyncing;
  bool get isRestoring => _isRestoring;
  bool get isSyncing => _isBatchSyncing || _isRestoring || _syncingDocIds.isNotEmpty;
  String? get lastError => _lastError;
  int get lastRestoredCount => _lastRestoredCount;

  bool isDocSyncing(String docId) => _syncingDocIds.contains(docId);

  Future<void> init() async {
    try {
      _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
        _currentUser = account;
        if (account == null) {
          _cachedFolderId = null;
          _cachedManifestId = null;
        }
        StorageService().setActiveAccount(account?.email);
        notifyListeners();
      });
      _currentUser = await _googleSignIn.signInSilently();
      await StorageService().setActiveAccount(_currentUser?.email);
      notifyListeners();

      // Automatically restore any cloud-backed PDFs if local library is empty after reinstall
      if (_currentUser != null) {
        Future.microtask(() async {
          await _registerUserInFirebaseAuth(_currentUser!);
          await restoreFromDrive();
          if (StorageService().settings.autoSyncToDrive) {
            await syncAllPendingDocuments();
          }
        });
      }
    } catch (e) {
      debugPrint('GoogleDriveService silent sign-in skipped: $e');
    }
  }

  /// Registers the Google Sign-In session with Firebase Authentication REST API
  /// so every signed-in user appears in Firebase Console -> Authentication -> Users.
  Future<void> _registerUserInFirebaseAuth(GoogleSignInAccount account) async {
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        return;
      }

      final tokenParts = <String>[
        if (idToken != null && idToken.isNotEmpty) 'id_token=$idToken',
        if (accessToken != null && accessToken.isNotEmpty) 'access_token=$accessToken',
        'providerId=google.com',
      ];

      final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$_kFirebaseApiKey',
      );
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'postBody': tokenParts.join('&'),
          'requestUri': 'http://localhost',
          'returnIdpCredential': true,
          'returnSecureToken': true,
        }),
      );
    } catch (e) {
      debugPrint('Firebase Auth user sync skipped: $e');
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
      await StorageService().setActiveAccount(account?.email);

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
        // Register user in Firebase Console -> Authentication -> Users
        await _registerUserInFirebaseAuth(account);
        // First restore any documents from Google Drive (e.g. after app reinstall)
        await restoreFromDrive();
        // Then upload any new local documents belonging to this account
        if (StorageService().settings.autoSyncToDrive) {
          await syncAllPendingDocuments();
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
    _cachedManifestId = null;
    _lastError = null;
    await StorageService().setActiveAccount(null);
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

  /// Uploads/updates `scanora_metadata.json` in the `"Scanora Documents"` Drive folder
  /// so folders, passwords, watermarks, and vault flags are preserved across reinstalls.
  Future<void> _uploadCloudManifest(
    Map<String, String> authHeaders,
    String folderId,
  ) async {
    try {
      final storage = StorageService();
      final payload = jsonEncode({
        'updatedAt': DateTime.now().toIso8601String(),
        'folders': storage.folders.map((f) => f.toJson()).toList(),
        'documents': storage.documents.map((d) => d.toJson()).toList(),
      });
      final payloadBytes = utf8.encode(payload);

      if (_cachedManifestId == null) {
        final q = Uri.encodeQueryComponent(
          "name = '$kDriveManifestName' and '$folderId' in parents and trashed = false",
        );
        final searchUri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=$q&spaces=drive&fields=files(id,name)',
        );
        final searchRes = await http.get(searchUri, headers: authHeaders);
        if (searchRes.statusCode == 200) {
          final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
          final files = data['files'] as List<dynamic>? ?? [];
          if (files.isNotEmpty) {
            _cachedManifestId = (files.first as Map<String, dynamic>)['id'] as String?;
          }
        }
      }

      final isUpdate = _cachedManifestId != null && _cachedManifestId!.isNotEmpty;
      final metadata = <String, dynamic>{
        'name': kDriveManifestName,
        'mimeType': 'application/json',
        if (!isUpdate) 'parents': [folderId],
      };

      const boundary = 'scanora_manifest_boundary';
      final bodyBytes = BytesBuilder();
      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
      bodyBytes.add(utf8.encode('${jsonEncode(metadata)}\r\n'));
      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
      bodyBytes.add(payloadBytes);
      bodyBytes.add(utf8.encode('\r\n--$boundary--\r\n'));

      final uploadUri = isUpdate
          ? Uri.parse(
              'https://www.googleapis.com/upload/drive/v3/files/$_cachedManifestId?uploadType=multipart&fields=id',
            )
          : Uri.parse(
              'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id',
            );

      final headers = {
        ...authHeaders,
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Content-Length': bodyBytes.length.toString(),
      };

      final res = isUpdate
          ? await http.patch(uploadUri, headers: headers, body: bodyBytes.toBytes())
          : await http.post(uploadUri, headers: headers, body: bodyBytes.toBytes());

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedManifestId = data['id'] as String?;
      }
    } catch (e) {
      debugPrint('Cloud manifest upload skipped: $e');
    }
  }

  /// Restores any PDFs and folders from the user's `"Scanora Documents"` folder on Google Drive
  /// that are missing locally (e.g. after uninstalling and reinstalling the app).
  Future<int> restoreFromDrive() async {
    if (_currentUser == null || _isRestoring) return 0;

    _isRestoring = true;
    _lastRestoredCount = 0;
    notifyListeners();

    int restoredCount = 0;
    try {
      Map<String, String> authHeaders = await _currentUser!.authHeaders;
      String? folderId = await _getOrCreateScanoraFolder(authHeaders);

      if (folderId == null) {
        final granted = await _googleSignIn.requestScopes(<String>[kDriveFileScope]);
        if (granted) {
          authHeaders = await _currentUser!.authHeaders;
          folderId = await _getOrCreateScanoraFolder(authHeaders);
        }
      }

      if (folderId == null) {
        _isRestoring = false;
        notifyListeners();
        return 0;
      }

      final storage = StorageService();
      final Map<String, Map<String, dynamic>> metaByDriveId = {};
      final Map<String, Map<String, dynamic>> metaByTitle = {};

      // 1. Download scanora_metadata.json if present to restore folders and document security metadata
      final manifestQuery = Uri.encodeQueryComponent(
        "name = '$kDriveManifestName' and '$folderId' in parents and trashed = false",
      );
      final manifestSearchUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$manifestQuery&spaces=drive&fields=files(id,name)',
      );
      final manifestSearchRes = await http.get(manifestSearchUri, headers: authHeaders);
      if (manifestSearchRes.statusCode == 200) {
        final searchData = jsonDecode(manifestSearchRes.body) as Map<String, dynamic>;
        final manifestFiles = searchData['files'] as List<dynamic>? ?? [];
        if (manifestFiles.isNotEmpty) {
          final manifestId = (manifestFiles.first as Map<String, dynamic>)['id'] as String?;
          _cachedManifestId = manifestId;
          if (manifestId != null) {
            final dlRes = await http.get(
              Uri.parse('https://www.googleapis.com/drive/v3/files/$manifestId?alt=media'),
              headers: authHeaders,
            );
            if (dlRes.statusCode == 200) {
              try {
                final manifestJson = jsonDecode(dlRes.body) as Map<String, dynamic>;
                if (manifestJson['folders'] is List) {
                  for (final fRaw in manifestJson['folders'] as List) {
                    if (fRaw is Map<String, dynamic>) {
                      await storage.mergeRestoredFolder(DocumentFolder.fromJson(fRaw));
                    }
                  }
                }
                if (manifestJson['documents'] is List) {
                  for (final dRaw in manifestJson['documents'] as List) {
                    if (dRaw is Map<String, dynamic>) {
                      final dDriveId = dRaw['driveFileId'] as String?;
                      final dTitle = (dRaw['title'] as String? ?? '').trim().toLowerCase();
                      if (dDriveId != null && dDriveId.isNotEmpty) {
                        metaByDriveId[dDriveId] = dRaw;
                      }
                      if (dTitle.isNotEmpty) {
                        metaByTitle[dTitle] = dRaw;
                      }
                    }
                  }
                }
              } catch (_) {}
            }
          }
        }
      }

      // 2. List all PDF files in "Scanora Documents" on Google Drive
      final pdfQuery = Uri.encodeQueryComponent(
        "mimeType = 'application/pdf' and '$folderId' in parents and trashed = false",
      );
      final pdfListUri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$pdfQuery&spaces=drive&pageSize=100&fields=files(id,name,size,createdTime,modifiedTime)',
      );
      final pdfListRes = await http.get(pdfListUri, headers: authHeaders);
      if (pdfListRes.statusCode != 200) {
        _isRestoring = false;
        notifyListeners();
        return 0;
      }

      final listData = jsonDecode(pdfListRes.body) as Map<String, dynamic>;
      final driveFiles = listData['files'] as List<dynamic>? ?? [];

      for (final item in driveFiles) {
        if (item is! Map<String, dynamic>) continue;
        final driveFileId = item['id'] as String?;
        final rawName = item['name'] as String? ?? 'Scanned_Document.pdf';
        if (driveFileId == null || driveFileId.isEmpty) continue;

        final cleanTitle = rawName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').trim();

        // Check if already present locally with a valid file on disk for this account
        final existingDoc = storage.findExistingDocForDriveRestore(
          driveFileId: driveFileId,
          cleanTitle: cleanTitle,
          accountEmail: _currentUser?.email ?? '',
        );

        if (existingDoc != null && await File(existingDoc.filePath).exists()) {
          // Ensure driveFileId and ownerEmail are linked
          await storage.updateDocument(
            existingDoc.copyWith(
              driveFileId: driveFileId,
              syncedAt: DateTime.now(),
              ownerEmail: _currentUser?.email.trim().toLowerCase(),
            ),
          );
          continue;
        }

        // Download the PDF from Google Drive to local app storage
        final dlUri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$driveFileId?alt=media',
        );
        final dlRes = await http.get(dlUri, headers: authHeaders);
        if (dlRes.statusCode != 200 || dlRes.bodyBytes.isEmpty) continue;

        final pdfBytes = dlRes.bodyBytes;
        final sanitizedTitle = FileUtils.sanitizeFileName(cleanTitle);
        final localPdfPath = await FileService().createPdfPath(sanitizedTitle);
        final localPdfFile = File(localPdfPath);
        await localPdfFile.writeAsBytes(pdfBytes, flush: true);

        final savedMeta = metaByDriveId[driveFileId] ?? metaByTitle[cleanTitle.toLowerCase()];
        final docId = (savedMeta?['id'] as String?) ??
            existingDoc?.id ??
            'doc_${DateTime.now().millisecondsSinceEpoch}_${driveFileId.hashCode.abs()}';
        final password = savedMeta?['password'] as String?;
        final isEncrypted = (savedMeta?['isEncrypted'] as bool?) ??
            (password != null && password.isNotEmpty);
        final watermarkText = savedMeta?['watermarkText'] as String?;
        final isVaultLocked = (savedMeta?['isVaultLocked'] as bool?) ?? false;
        final isFavorite = (savedMeta?['isFavorite'] as bool?) ?? false;
        final folderIdMeta = savedMeta?['folderId'] as String?;

        int pageCount = (savedMeta?['pageCount'] as int?) ?? 1;
        String previewPdfPath = localPdfPath;

        // Inspect page count and create unlocked sidecar if password-protected
        try {
          final pdfDoc = (password != null && password.isNotEmpty)
              ? PdfDocument(inputBytes: pdfBytes, password: password)
              : PdfDocument(inputBytes: pdfBytes);
          pageCount = pdfDoc.pages.count;

          if (password != null && password.isNotEmpty) {
            pdfDoc.security.userPassword = '';
            pdfDoc.security.ownerPassword = '';
            final unlockedBytes = Uint8List.fromList(await pdfDoc.save());
            final unlockedFile = File('$localPdfPath.unlocked');
            await unlockedFile.writeAsBytes(unlockedBytes, flush: true);
            previewPdfPath = unlockedFile.path;
          }
          pdfDoc.dispose();
        } catch (_) {}

        // Generate thumbnail from restored PDF
        String? thumbPath;
        try {
          thumbPath = await PdfThumbnailService().createThumbnailFromPdf(
            previewPdfPath,
            docId,
          );
        } catch (_) {}

        final createdAt = DateTime.tryParse(
              (savedMeta?['createdAt'] as String?) ?? (item['createdTime'] as String? ?? ''),
            ) ??
            DateTime.now();
        final modifiedAt = DateTime.tryParse(
              (savedMeta?['modifiedAt'] as String?) ?? (item['modifiedTime'] as String? ?? ''),
            ) ??
            DateTime.now();

        final restoredDoc = ScannedDocument(
          id: docId,
          title: cleanTitle,
          filePath: localPdfPath,
          thumbnailPath: thumbPath,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          pageCount: pageCount,
          fileSizeBytes: pdfBytes.length,
          isFavorite: isFavorite,
          folderId: folderIdMeta,
          isEncrypted: isEncrypted,
          password: password,
          watermarkText: watermarkText,
          isVaultLocked: isVaultLocked,
          driveFileId: driveFileId,
          syncedAt: DateTime.now(),
          ownerEmail: _currentUser?.email.trim().toLowerCase(),
        );

        await storage.mergeRestoredDocument(restoredDoc);
        restoredCount++;
      }
    } catch (e) {
      debugPrint('Google Drive restore error: $e');
    } finally {
      _lastRestoredCount = restoredCount;
      _isRestoring = false;
      notifyListeners();
    }

    return restoredCount;
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
            ownerEmail: _currentUser?.email.trim().toLowerCase(),
          );
          await StorageService().updateDocument(updated);
          if (folderId != null) {
            await _uploadCloudManifest(authHeaders, folderId);
          }
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

      if (_cachedFolderId != null) {
        final authHeaders = await _currentUser!.authHeaders;
        await _uploadCloudManifest(authHeaders, _cachedFolderId!);
      }
    } finally {
      _isBatchSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  Future<int> syncAllUnsyncedDocuments() async {
    final restored = await restoreFromDrive();
    final uploaded = await syncAllPendingDocuments();
    return restored + uploaded;
  }
}
