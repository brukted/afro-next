import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceLayoutPreferences {
  const WorkspaceLayoutPreferences({
    required this.leftPaneWidth,
    required this.inspectorWidth,
  });

  final double leftPaneWidth;
  final double inspectorWidth;

  Map<String, Object> toJson() {
    return {
      'leftPaneWidth': leftPaneWidth,
      'inspectorWidth': inspectorWidth,
    };
  }

  factory WorkspaceLayoutPreferences.fromJson(Map<String, dynamic> json) {
    return WorkspaceLayoutPreferences(
      leftPaneWidth: (json['leftPaneWidth'] as num?)?.toDouble() ?? 260,
      inspectorWidth: (json['inspectorWidth'] as num?)?.toDouble() ?? 320,
    );
  }
}

class AppPreferences {
  AppPreferences(SharedPreferences prefs)
      : _prefs = prefs,
        _memoryStore = <String, Object>{};

  AppPreferences.memory()
      : _prefs = null,
        _memoryStore = <String, Object>{};

  final SharedPreferences? _prefs;
  final Map<String, Object> _memoryStore;

  static const _workspaceLayoutKey = 'workspace.layout';
  static const _recentFilesKey = 'workspace.recentFiles';

  WorkspaceLayoutPreferences loadWorkspaceLayout() {
    final rawValue = _readString(_workspaceLayoutKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const WorkspaceLayoutPreferences(
        leftPaneWidth: 260,
        inspectorWidth: 320,
      );
    }

    final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
    return WorkspaceLayoutPreferences.fromJson(decoded);
  }

  Future<void> saveWorkspaceLayout(WorkspaceLayoutPreferences layout) async {
    final encoded = jsonEncode(layout.toJson());
    await _writeString(_workspaceLayoutKey, encoded);
  }

  List<String> loadRecentFiles() {
    if (_prefs != null) {
      return _prefs.getStringList(_recentFilesKey) ?? const <String>[];
    }

    return (_memoryStore[_recentFilesKey] as List<String>?) ?? const <String>[];
  }

  Future<void> rememberRecentFile(String path) async {
    final entries = loadRecentFiles()
        .where((entry) => entry != path)
        .toList(growable: true)
      ..insert(0, path);

    final trimmed = entries.take(6).toList(growable: false);

    if (_prefs != null) {
      await _prefs.setStringList(_recentFilesKey, trimmed);
      return;
    }

    _memoryStore[_recentFilesKey] = trimmed;
  }

  String? _readString(String key) {
    if (_prefs != null) {
      return _prefs.getString(key);
    }

    return _memoryStore[key] as String?;
  }

  Future<void> _writeString(String key, String value) async {
    if (_prefs != null) {
      await _prefs.setString(key, value);
      return;
    }

    _memoryStore[key] = value;
  }
}
