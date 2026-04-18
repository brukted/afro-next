import 'dart:convert';
import 'dart:io';

import '../../features/workspace/models/workspace_models.dart';

class WorkspaceFileStore {
  const WorkspaceFileStore();

  Future<WorkspaceProjectDocument> load(String path) async {
    final file = File(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return WorkspaceProjectDocument.fromJson(json);
  }

  Future<void> save({
    required String path,
    required WorkspaceProjectDocument workspace,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final contents = const JsonEncoder.withIndent('  ').convert(workspace.toJson());
    await file.writeAsString('$contents\n');
  }
}
