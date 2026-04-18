import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/features/workspace/models/workspace_models.dart';
import 'package:eyecandy/features/workspace/workspace_controller.dart';

void main() {
  test('creates graphs inside an explicit folder', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final materialsFolder = controller.workspace.resources.firstWhere(
      (entry) => entry.name == 'Materials',
    );
    final initialChildren = controller.childrenOf(materialsFolder.id).length;

    controller.createMaterialGraphAt(materialsFolder.id);

    final created = controller.openedResource!;
    expect(created.kind, WorkspaceResourceKind.materialGraph);
    expect(created.parentId, materialsFolder.id);
    expect(controller.childrenOf(materialsFolder.id).length, initialChildren + 1);
    expect(
      controller.workspace.materialGraphs.any(
        (entry) => entry.id == created.documentId,
      ),
      isTrue,
    );
  });

  test('renames graph resources and their backing documents', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final resource = controller.openedResource!;

    controller.renameResource(resourceId: resource.id, nextName: 'Surface');

    expect(controller.resourceById(resource.id)?.name, 'Surface');
    expect(controller.openedMaterialGraphDocument?.graph.name, 'Surface');
  });

  test('selection does not change the opened resource', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final initiallyOpenedId = controller.openedResourceId;
    final mathGraph = controller.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.mathGraph,
    );

    controller.selectResource(mathGraph.id);

    expect(controller.selectedResourceId, mathGraph.id);
    expect(controller.openedResourceId, initiallyOpenedId);
  });

  test('opening a resource updates both selection and editor target', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final mathGraph = controller.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.mathGraph,
    );

    controller.openResource(mathGraph.id);

    expect(controller.selectedResourceId, mathGraph.id);
    expect(controller.openedResourceId, mathGraph.id);
    expect(controller.openedMathGraphDocument?.id, mathGraph.documentId);
  });

  test('deletes folders recursively and removes nested documents', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final materialsFolder = controller.workspace.resources.firstWhere(
      (entry) => entry.name == 'Materials',
    );

    controller.deleteResource(materialsFolder.id);

    expect(
      controller.workspace.resources.any((entry) => entry.id == materialsFolder.id),
      isFalse,
    );
    expect(
      controller.workspace.resources.any(
        (entry) => entry.parentId == materialsFolder.id,
      ),
      isFalse,
    );
    expect(controller.workspace.materialGraphs, isEmpty);
    expect(controller.selectedResourceId, controller.workspace.rootFolderId);
  });
}
