import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String defaultPageSize; // 'A4', 'Letter'
  final bool isBiometricLockEnabled;
  final String defaultWatermark;
  final bool autoSyncToDrive;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultPageSize = 'A4',
    this.isBiometricLockEnabled = false,
    this.defaultWatermark = 'CONFIDENTIAL',
    this.autoSyncToDrive = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultPageSize,
    bool? isBiometricLockEnabled,
    String? defaultWatermark,
    bool? autoSyncToDrive,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      isBiometricLockEnabled: isBiometricLockEnabled ?? this.isBiometricLockEnabled,
      defaultWatermark: defaultWatermark ?? this.defaultWatermark,
      autoSyncToDrive: autoSyncToDrive ?? this.autoSyncToDrive,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'defaultPageSize': defaultPageSize,
    'isBiometricLockEnabled': isBiometricLockEnabled,
    'defaultWatermark': defaultWatermark,
    'autoSyncToDrive': autoSyncToDrive,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
    defaultPageSize: json['defaultPageSize'] as String? ?? 'A4',
    isBiometricLockEnabled: json['isBiometricLockEnabled'] as bool? ?? false,
    defaultWatermark: json['defaultWatermark'] as String? ?? 'CONFIDENTIAL',
    autoSyncToDrive: json['autoSyncToDrive'] as bool? ?? true,
  );
}
