import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/file_utils.dart';
import '../models/app_settings.dart';
import '../models/document_folder.dart';
import '../models/scanned_document.dart';
import 'file_service.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _kDocumentsKey = 'scanora_documents_v1';
  static const String _kFoldersKey = 'scanora_folders_v1';
  static const String _kSettingsKey = 'scanora_settings_v1';
  static const String _kActiveAccountKey = 'scanora_active_account_v1';

  List<ScannedDocument> _documents = [];
  List<DocumentFolder> _folders = [];
  AppSettings _settings = const AppSettings();
  String? _activeAccountEmail;
  bool _isInitialized = false;

  String? get activeAccountEmail => _activeAccountEmail;

  List<ScannedDocument> get _visibleDocuments {
    if (_activeAccountEmail != null && _activeAccountEmail!.isNotEmpty) {
      return _documents.where((d) {
        final owner = d.ownerEmail?.trim().toLowerCase();
        if (owner != null && owner.isNotEmpty) {
          return owner == _activeAccountEmail;
        }
        // Only show untagged local documents that haven't been synced to another account
        return !d.isCloudSynced;
      }).toList();
    }
    // When signed out, hide documents owned by or synced to a specific Google account
    return _documents.where((d) {
      final owner = d.ownerEmail?.trim().toLowerCase();
      return (owner == null || owner.isEmpty) && !d.isCloudSynced;
    }).toList();
  }

  List<ScannedDocument> get documents => List.unmodifiable(_visibleDocuments);
  List<DocumentFolder> get folders => List.unmodifiable(_folders);
  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  List<ScannedDocument> get recentDocuments {
    final sorted = List<ScannedDocument>.from(_visibleDocuments)
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return sorted.take(6).toList();
  }

  List<ScannedDocument> get favoriteDocuments {
    return _visibleDocuments.where((d) => d.isFavorite).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  Future<void> setActiveAccount(String? email) async {
    final normalized = email?.trim().toLowerCase();
    final nextVal = (normalized != null && normalized.isNotEmpty) ? normalized : null;
    if (_activeAccountEmail == nextVal) return;
    _activeAccountEmail = nextVal;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeAccountEmail != null) {
        await prefs.setString(_kActiveAccountKey, _activeAccountEmail!);
      } else {
        await prefs.remove(_kActiveAccountKey);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeAccountEmail = prefs.getString(_kActiveAccountKey);

    // Load Settings
    final settingsRaw = prefs.getString(_kSettingsKey);
    if (settingsRaw != null) {
      try {
        _settings = AppSettings.fromJson(jsonDecode(settingsRaw));
      } catch (_) {
        _settings = const AppSettings();
      }
    }

    // Load Folders
    final foldersRaw = prefs.getString(_kFoldersKey);
    if (foldersRaw != null) {
      try {
        final List<dynamic> list = jsonDecode(foldersRaw);
        _folders = list.map((e) => DocumentFolder.fromJson(e)).toList();
      } catch (_) {
        _folders = [];
      }
    }

    // Load Documents
    final docsRaw = prefs.getString(_kDocumentsKey);
    if (docsRaw != null) {
      try {
        final List<dynamic> list = jsonDecode(docsRaw);
        _documents = list.map((e) => ScannedDocument.fromJson(e)).toList();
      } catch (_) {
        _documents = [];
      }
    }

    await _recoverFromLocalDiskIfNeeded();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _writeLocalManifestBackup() async {
    try {
      final dPath = await FileService().documentsPath;
      final manifestFile = File('$dPath/scanora_library_backup.json');
      final payload = {
        'updatedAt': DateTime.now().toIso8601String(),
        'folders': _folders.map((f) => f.toJson()).toList(),
        'documents': _documents.map((d) => d.toJson()).toList(),
      };
      await manifestFile.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {}
  }

  Future<void> _recoverFromLocalDiskIfNeeded() async {
    try {
      final dPath = await FileService().documentsPath;
      final dir = Directory(dPath);
      if (!await dir.exists()) return;

      // 1. If SharedPreferences had no documents/folders, check local manifest backup
      final manifestFile = File('$dPath/scanora_library_backup.json');
      if (_documents.isEmpty && await manifestFile.exists()) {
        try {
          final map = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
          if (_folders.isEmpty && map['folders'] is List) {
            _folders = (map['folders'] as List)
                .map((e) => DocumentFolder.fromJson(e as Map<String, dynamic>))
                .toList();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _kFoldersKey,
              jsonEncode(_folders.map((f) => f.toJson()).toList()),
            );
          }
          if (map['documents'] is List) {
            final recoveredDocs = (map['documents'] as List)
                .map((e) => ScannedDocument.fromJson(e as Map<String, dynamic>))
                .where((d) => File(d.filePath).existsSync())
                .toList();
            if (recoveredDocs.isNotEmpty) {
              _documents = recoveredDocs;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                _kDocumentsKey,
                jsonEncode(_documents.map((d) => d.toJson()).toList()),
              );
            }
          }
        } catch (_) {}
      }

      // 2. Discover any orphaned .pdf files in scanora_documents not yet tracked
      final existingPaths = _documents.map((d) => d.filePath).toSet();
      bool addedOrphan = false;
      for (final entity in dir.listSync()) {
        if (entity is File &&
            entity.path.toLowerCase().endsWith('.pdf') &&
            !existingPaths.contains(entity.path)) {
          final stat = await entity.stat();
          final fileName = entity.uri.pathSegments.last;
          final title = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
          final docId = 'doc_${stat.modified.millisecondsSinceEpoch}_${title.hashCode.abs()}';
          _documents.add(
            ScannedDocument(
              id: docId,
              title: title,
              filePath: entity.path,
              createdAt: stat.changed,
              modifiedAt: stat.modified,
              pageCount: 1,
              fileSizeBytes: stat.size,
            ),
          );
          addedOrphan = true;
        }
      }
      if (addedOrphan) {
        _documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _kDocumentsKey,
          jsonEncode(_documents.map((d) => d.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_documents.map((d) => d.toJson()).toList());
    await prefs.setString(_kDocumentsKey, encoded);
    await _writeLocalManifestBackup();
    notifyListeners();
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_folders.map((f) => f.toJson()).toList());
    await prefs.setString(_kFoldersKey, encoded);
    await _writeLocalManifestBackup();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_settings.toJson());
    await prefs.setString(_kSettingsKey, encoded);
    notifyListeners();
  }

  // Document Operations
  ScannedDocument? getDocument(String docId) {
    try {
      return _documents.firstWhere((d) => d.id == docId);
    } catch (_) {
      return null;
    }
  }

  ScannedDocument? findExistingDocForDriveRestore({
    required String driveFileId,
    required String cleanTitle,
    required String accountEmail,
  }) {
    final normalizedEmail = accountEmail.trim().toLowerCase();
    for (final d in _documents) {
      final dOwner = d.ownerEmail?.trim().toLowerCase();
      // Match by exact Google Drive File ID (if owned by this account or legacy untagged)
      if (d.driveFileId == driveFileId &&
          (dOwner == null || dOwner.isEmpty || dOwner == normalizedEmail)) {
        return d;
      }
      // Or match by title if already owned by this same account
      if (dOwner == normalizedEmail &&
          d.title.trim().toLowerCase() == cleanTitle.trim().toLowerCase()) {
        return d;
      }
    }
    return null;
  }

  Future<void> addDocument(ScannedDocument doc) async {
    final taggedDoc = (_activeAccountEmail != null &&
            _activeAccountEmail!.isNotEmpty &&
            (doc.ownerEmail == null || doc.ownerEmail!.isEmpty))
        ? doc.copyWith(ownerEmail: _activeAccountEmail)
        : doc;
    _documents.insert(0, taggedDoc);
    await _saveDocuments();
  }

  Future<void> mergeRestoredFolder(DocumentFolder folder) async {
    final existingIdx = _folders.indexWhere(
      (f) => f.id == folder.id || f.name.toLowerCase() == folder.name.toLowerCase(),
    );
    if (existingIdx == -1) {
      _folders.add(folder);
      await _saveFolders();
    }
  }

  Future<void> mergeRestoredDocument(ScannedDocument restoredDoc) async {
    final existingIdx = _documents.indexWhere(
      (d) =>
          d.id == restoredDoc.id ||
          (restoredDoc.driveFileId != null && d.driveFileId == restoredDoc.driveFileId),
    );
    if (existingIdx != -1) {
      _documents[existingIdx] = restoredDoc;
    } else {
      _documents.add(restoredDoc);
    }
    _documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    await _saveDocuments();
  }

  Future<void> updateDocument(ScannedDocument updatedDoc) async {
    final index = _documents.indexWhere((d) => d.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;
      await _saveDocuments();
    }
  }

  Future<void> toggleFavorite(String docId) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      _documents[index] = doc.copyWith(isFavorite: !doc.isFavorite);
      await _saveDocuments();
    }
  }

  Future<void> renameDocument(String docId, String newTitle) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      String updatedFilePath = doc.filePath;

      try {
        final currentFile = File(doc.filePath);
        if (await currentFile.exists()) {
          final parentDir = currentFile.parent.path;
          final sanitized = FileUtils.sanitizeFileName(newTitle);
          final newPath = '$parentDir/$sanitized.pdf';
          if (newPath != doc.filePath) {
            final renamed = await currentFile.rename(newPath);
            updatedFilePath = renamed.path;
            // Also rename unlocked sidecar if present
            final unlockedFile = File('${doc.filePath}.unlocked');
            if (await unlockedFile.exists()) {
              await unlockedFile.rename('$updatedFilePath.unlocked');
            }
          }
        }
      } catch (_) {
        // Fallback: preserve existing file path if OS file rename fails
      }

      _documents[index] = doc.copyWith(
        title: newTitle,
        filePath: updatedFilePath,
        modifiedAt: DateTime.now(),
      );
      await _saveDocuments();
    }
  }

  Future<void> moveDocumentToFolder(String docId, String? folderId) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      bool vaultLock = doc.isVaultLocked;
      if (folderId != null) {
        final targetFolder = _folders.where((f) => f.id == folderId).firstOrNull;
        if (targetFolder != null && targetFolder.isLocked) {
          vaultLock = true;
        }
      }
      _documents[index] = doc.copyWith(
        folderId: folderId,
        clearFolder: folderId == null,
        isVaultLocked: vaultLock,
        modifiedAt: DateTime.now(),
      );
      await _saveDocuments();
    }
  }

  Future<void> deleteDocument(String docId) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      final doc = _documents[index];
      _documents.removeAt(index);
      await _saveDocuments();

      // Clean up files in local storage
      await FileService().deleteDocumentFiles(doc.filePath, doc.thumbnailPath);
      try {
        final unlockedFile = File('${doc.filePath}.unlocked');
        if (await unlockedFile.exists()) {
          await unlockedFile.delete();
        }
      } catch (_) {}
    }
  }

  List<ScannedDocument> getDocumentsInFolder(String? folderId) {
    if (folderId == null) {
      return _visibleDocuments.where((d) => d.folderId == null).toList();
    }
    return _visibleDocuments.where((d) => d.folderId == folderId).toList();
  }

  int getDocumentCountInFolder(String folderId) {
    return _visibleDocuments.where((d) => d.folderId == folderId).length;
  }

  // Folder Operations
  Future<DocumentFolder> createFolder(
    String name, {
    int colorValue = 0xFFEA580C,
    bool isLocked = false,
  }) async {
    final folder = DocumentFolder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      colorValue: colorValue,
      createdAt: DateTime.now(),
      isLocked: isLocked,
    );
    _folders.add(folder);
    await _saveFolders();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index] = _folders[index].copyWith(name: newName.trim());
      await _saveFolders();
    }
  }

  Future<void> deleteFolder(String folderId) async {
    for (int i = 0; i < _documents.length; i++) {
      if (_documents[i].folderId == folderId) {
        _documents[i] = _documents[i].copyWith(clearFolder: true);
      }
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _saveDocuments();
    await _saveFolders();
  }

  // Settings & Security Operations
  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _saveSettings();
  }

  Future<void> updateDefaultPageSize(String size) async {
    _settings = _settings.copyWith(defaultPageSize: size);
    await _saveSettings();
  }

  Future<void> toggleBiometricLock(bool enabled) async {
    _settings = _settings.copyWith(isBiometricLockEnabled: enabled);
    await _saveSettings();
  }

  Future<void> updateDefaultWatermark(String watermark) async {
    _settings = _settings.copyWith(defaultWatermark: watermark.trim());
    await _saveSettings();
  }

  Future<void> updateAutoSyncToDrive(bool enabled) async {
    _settings = _settings.copyWith(autoSyncToDrive: enabled);
    await _saveSettings();
  }

  Future<void> toggleDocumentVaultLock(String docId) async {
    final index = _documents.indexWhere((d) => d.id == docId);
    if (index != -1) {
      _documents[index] = _documents[index].copyWith(
        isVaultLocked: !_documents[index].isVaultLocked,
        modifiedAt: DateTime.now(),
      );
      await _saveDocuments();
    }
  }

  Future<void> toggleFolderLock(String folderId) async {
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      final newLockState = !_folders[index].isLocked;
      _folders[index] = _folders[index].copyWith(isLocked: newLockState);
      await _saveFolders();
    }
  }
}
