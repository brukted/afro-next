import 'dart:convert';
import 'dart:io';

import '../../features/material_graph/material_graph_migration.dart';
import '../../features/workspace/models/workspace_models.dart';

class WorkspaceFileStore {
  const WorkspaceFileStore();

  Future<WorkspaceProjectDocument> load(String path) async {
    final file = File(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final workspace = WorkspaceProjectDocument.fromJson(json);
    return workspace.copyWith(
      materialGraphs: workspace.materialGraphs
          .map(
            (entry) => entry.copyWith(
              graph: MaterialGraphMigration.normalize(entry.graph),
            ),
          )
          .toList(growable: false),
    );
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
