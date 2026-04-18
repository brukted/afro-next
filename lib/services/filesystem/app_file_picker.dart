import 'package:file_selector/file_selector.dart';

class AppFilePicker {
  const AppFilePicker({bool interactive = true}) : _interactive = interactive;

  const AppFilePicker.noop() : _interactive = false;

  final bool _interactive;

  Future<String?> openWorkspaceFile() async {
    if (!_interactive) {
      return null;
    }

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Eyecandy graph',
          extensions: ['json', 'eye'],
        ),
      ],
    );

    return file?.path;
  }

  Future<String?> saveWorkspaceFile({
    String suggestedName = 'material_graph.eye',
  }) async {
    if (!_interactive) {
      return null;
    }

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Eyecandy graph',
          extensions: ['json', 'eye'],
        ),
      ],
    );

    return location?.path;
  }
}
