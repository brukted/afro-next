import 'dart:io';
import 'dart:ui' as ui;

import 'package:eyecandy/app/theme/app_theme.dart';
import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/features/property_editor/color_curve_editor.dart';
import 'package:eyecandy/features/property_editor/property_editor_panel.dart';
import 'package:eyecandy/features/workspace/workspace_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

void main() {
  testWidgets('circle properties expose both sliders and hard inputs', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final graph = catalog.createStarterGraph(name: 'Test');
    final circleNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'circle_node',
    );

    controller.bindGraph(graph: graph, onChanged: (_) {});
    controller.selectNode(circleNode.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: PropertyEditorPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Radius'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('Width'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(4));
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('mix node exposes compact dropdowns and a color picker dialog', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final graph = catalog.createStarterGraph(name: 'Test');
    final mixNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );

    controller.bindGraph(graph: graph, onChanged: (_) {});
    controller.selectNode(mixNode.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: PropertyEditorPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Pick'), findsNWidgets(2));

    await tester.tap(find.text('Pick').first);
    await tester.pumpAndSettle();

    expect(find.text('Pick Color'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('curve demo node exposes the bezier curve editor', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final graph = catalog.createStarterGraph(name: 'Test');
    final curveNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'curve_demo_node',
    );

    controller.bindGraph(graph: graph, onChanged: (_) {});
    controller.selectNode(curveNode.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 760,
            child: PropertyEditorPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byType(ColorBezierCurveEditor), findsOneWidget);
    expect(find.text('Double-click to add a point'), findsOneWidget);
  });

  testWidgets('gradient map node exposes editable gradient fallback', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final gradientNode = catalog.instantiateNode(
      definitionId: 'gradientmap_node',
      position: Vector2.zero(),
    );
    final graph = GraphDocument(
      id: 'gradient-graph',
      name: 'Gradient',
      nodes: [gradientNode],
      links: const [],
    );

    controller.bindGraph(graph: graph, onChanged: (_) {});
    controller.selectNode(gradientNode.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 760,
            child: PropertyEditorPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Add Stop'), findsOneWidget);
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('image and text nodes expose resource and text editors', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final workspaceController = WorkspaceController.preview()..initializeForPreview();
    final tempDir = await Directory.systemTemp.createTemp('eyecandy-props');
    addTearDown(() => tempDir.delete(recursive: true));
    final imagePath = '${tempDir.path}/preview.png';
    await File(imagePath).writeAsBytes(await _createPngBytes());
    await workspaceController.importImageFileAt(
      imagePath,
      workspaceController.workspace.rootFolderId,
    );

    final imageNode = catalog.instantiateNode(
      definitionId: 'image_node',
      position: Vector2.zero(),
    );
    final textNode = catalog.instantiateNode(
      definitionId: 'text_node',
      position: Vector2(120, 0),
    );
    final graph = GraphDocument(
      id: 'asset-graph',
      name: 'Assets',
      nodes: [imageNode, textNode],
      links: const [],
    );

    controller.bindGraph(graph: graph, onChanged: (_) {});
    controller.selectNode(imageNode.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 760,
            child: PropertyEditorPanel(
              controller: controller,
              workspaceController: workspaceController,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('None'), findsOneWidget);
    expect(find.text('preview.png'), findsOneWidget);

    controller.selectNode(textNode.id);
    await tester.pumpAndSettle();

    expect(find.text('Font Family'), findsOneWidget);
    expect(find.text('Background Color'), findsOneWidget);
    expect(find.text('Text Color'), findsOneWidget);
  });
}

Future<List<int>> _createPngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF4DA3FF),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}
