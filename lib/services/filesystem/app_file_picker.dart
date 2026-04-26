import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class AppFilePicker {
  const AppFilePicker({bool interactive = true}) : _interactive = interactive;

  const AppFilePicker.noop() : _interactive = false;

  final bool _interactive;
  static bool _macOsEntitlementsConfigured = false;

  Future<String?> openWorkspaceFile() async {
    return _pickSingleFilePath(
      dialogTitle: 'Open Workspace',
      allowedExtensions: const ['json', 'afro'],
    );
  }

  Future<String?> saveWorkspaceFile({
    String suggestedName = 'material_graph.afro',
  }) async {
    if (!_interactive) {
      return null;
    }

    await _preparePlatformPicker();
    return FilePicker.saveFile(
      dialogTitle: 'Save Workspace',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['json', 'afro'],
      lockParentWindow: true,
    );
  }

  Future<String?> openImageResourceFile() async {
    return _pickSingleFilePath(
      dialogTitle: 'Import Image',
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'],
    );
  }

  Future<String?> openSvgResourceFile() async {
    return _pickSingleFilePath(
      dialogTitle: 'Import SVG',
      allowedExtensions: const ['svg'],
    );
  }

  Future<String?> _pickSingleFilePath({
    required String dialogTitle,
    required List<String> allowedExtensions,
  }) async {
    if (!_interactive) {
      return null;
    }

    await _preparePlatformPicker();
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
      lockParentWindow: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.first.path;
  }

  Future<void> _preparePlatformPicker() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      if (_macOsEntitlementsConfigured) {
        return;
      }
      await FilePicker.skipEntitlementsChecks();
      _macOsEntitlementsConfigured = true;
    }
  }
}
