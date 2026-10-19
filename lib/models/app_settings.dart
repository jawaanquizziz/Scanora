import 'package:flutter/material.dart';

class AppSettings {
  final ThemeMode themeMode;
  final String defaultPageSize; // 'A4', 'Letter'

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultPageSize = 'A4',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultPageSize,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'defaultPageSize': defaultPageSize,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
    defaultPageSize: json['defaultPageSize'] as String? ?? 'A4',
  );
}
