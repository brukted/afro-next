import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/services/filesystem/workspace_file_store.dart';
import 'package:eyecandy/features/workspace/models/workspace_models.dart';
import 'package:eyecandy/features/workspace/workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(
      controller.childrenOf(materialsFolder.id).length,
      initialChildren + 1,
    );
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

  test('updates the active math graph document and resource name', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final mathGraph = controller.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.mathGraph,
    );
    controller.openResource(mathGraph.id);
    final document = controller.openedMathGraphDocument!;
    final updatedGraph = document.graph.copyWith(name: 'Math Surface');

    controller.updateActiveMathGraph(updatedGraph);

    expect(controller.resourceById(mathGraph.id)?.name, 'Math Surface');
    expect(controller.openedMathGraphDocument?.graph.name, 'Math Surface');
  });

  test('deletes folders recursively and removes nested documents', () {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final materialsFolder = controller.workspace.resources.firstWhere(
      (entry) => entry.name == 'Materials',
    );

    controller.deleteResource(materialsFolder.id);

    expect(
      controller.workspace.resources.any(
        (entry) => entry.id == materialsFolder.id,
      ),
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

  test('imports image and svg resources into the workspace', () async {
    final controller = WorkspaceController.preview()..initializeForPreview();
    final initiallyOpenedId = controller.openedResourceId;
    final tempDir = await Directory.systemTemp.createTemp('eyecandy-assets');
    addTearDown(() => tempDir.delete(recursive: true));

    final imagePath = '${tempDir.path}/checker.png';
    final svgPath = '${tempDir.path}/shape.svg';
    await File(imagePath).writeAsBytes(await _createPngBytes());
    await File(svgPath).writeAsString(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8">'
      '<rect width="8" height="8" fill="#ff00ff" />'
      '</svg>',
    );

    await controller.importImageFileAt(
      imagePath,
      controller.workspace.rootFolderId,
    );
    await controller.importSvgFileAt(
      svgPath,
      controller.workspace.rootFolderId,
    );

    final imageResource = controller.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.image,
    );
    final svgResource = controller.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.svg,
    );

    expect(
      controller.imageDocumentByResourceId(imageResource.id)?.sourceName,
      'checker.png',
    );
    expect(
      controller.svgDocumentByResourceId(svgResource.id)?.sourceName,
      'shape.svg',
    );
    expect(controller.selectedResourceId, svgResource.id);
    expect(controller.openedResourceId, initiallyOpenedId);
  });

  test(
    'opening a workspace file does not auto-open its initial resource',
    () async {
      final sourceController = WorkspaceController.preview()
        ..initializeForPreview();
      final tempDir = await Directory.systemTemp.createTemp(
        'eyecandy-workspace',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final workspacePath = '${tempDir.path}/sample.eyecandy.json';
      await const WorkspaceFileStore().save(
        path: workspacePath,
        workspace: sourceController.workspace,
      );

      final controller = WorkspaceController.preview()..initializeForPreview();

      await controller.openWorkspaceFromPath(workspacePath);

      expect(controller.selectedResourceId, isNotNull);
      expect(controller.openedResourceId, isNull);
      expect(controller.openedResource, isNull);
    },
  );
}

Future<List<int>> _createPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFFF00FF),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
