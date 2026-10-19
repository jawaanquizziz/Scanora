import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/file_utils.dart';
import '../models/scanned_document.dart';
import '../models/document_folder.dart';
import '../models/app_settings.dart';
import 'file_service.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _kDocumentsKey = 'scanora_scanned_documents';
  static const String _kFoldersKey = 'scanora_document_folders';
  static const String _kSettingsKey = 'scanora_app_settings';

  List<ScannedDocument> _documents = [];
  List<DocumentFolder> _folders = [];
  AppSettings _settings = const AppSettings();
  bool _isInitialized = false;

  List<ScannedDocument> get documents => List.unmodifiable(_documents);
  List<DocumentFolder> get folders => List.unmodifiable(_folders);
  AppSettings get settings => _settings;
  bool get isInitialized => _isInitialized;

  List<ScannedDocument> get recentDocuments {
    final list = List<ScannedDocument>.from(_documents);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<ScannedDocument> get favoriteDocuments {
    return _documents.where((d) => d.isFavorite).toList();
  }

  int get totalDocumentsCount => _documents.length;
  int get totalPagesScanned => _documents.fold<int>(0, (sum, d) => sum + d.pageCount);

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // Load Documents
    final docsJson = prefs.getString(_kDocumentsKey);
    if (docsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(docsJson) as List<dynamic>;
        _documents = decoded
            .map((item) => ScannedDocument.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _documents = [];
      }
    }

    // Load Folders
    final foldersJson = prefs.getString(_kFoldersKey);
    if (foldersJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(foldersJson) as List<dynamic>;
        _folders = decoded
            .map((item) => DocumentFolder.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _folders = [];
      }
    }

    // Load Settings
    final settingsJson = prefs.getString(_kSettingsKey);
    if (settingsJson != null) {
      try {
        _settings = AppSettings.fromJson(jsonDecode(settingsJson) as Map<String, dynamic>);
      } catch (_) {
        _settings = const AppSettings();
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_documents.map((d) => d.toJson()).toList());
    await prefs.setString(_kDocumentsKey, encoded);
    notifyListeners();
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_folders.map((f) => f.toJson()).toList());
    await prefs.setString(_kFoldersKey, encoded);
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_settings.toJson());
    await prefs.setString(_kSettingsKey, encoded);
    notifyListeners();
  }

  // Document Operations
  Future<void> addDocument(ScannedDocument doc) async {
    _documents.insert(0, doc);
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
      _documents[index] = doc.copyWith(
        folderId: folderId,
        clearFolder: folderId == null,
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
    }
  }

  List<ScannedDocument> getDocumentsInFolder(String? folderId) {
    if (folderId == null) {
      return _documents.where((d) => d.folderId == null).toList();
    }
    return _documents.where((d) => d.folderId == folderId).toList();
  }

  int getDocumentCountInFolder(String folderId) {
    return _documents.where((d) => d.folderId == folderId).length;
  }

  // Folder Operations
  Future<DocumentFolder> createFolder(String name, {int colorValue = 0xFFEA580C}) async {
    final folder = DocumentFolder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      colorValue: colorValue,
      createdAt: DateTime.now(),
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
    // Specification: Deleting a folder must NOT silently delete its documents.
    // Documents in this folder are moved back to root / unassigned.
    for (int i = 0; i < _documents.length; i++) {
      if (_documents[i].folderId == folderId) {
        _documents[i] = _documents[i].copyWith(clearFolder: true);
      }
    }
    _folders.removeWhere((f) => f.id == folderId);
    await _saveDocuments();
    await _saveFolders();
  }

  // Settings Operations
  Future<void> updateThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _saveSettings();
  }

  Future<void> updateDefaultPageSize(String size) async {
    _settings = _settings.copyWith(defaultPageSize: size);
    await _saveSettings();
  }
}
