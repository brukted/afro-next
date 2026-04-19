import 'package:eyecandy/app/theme/app_theme.dart';
import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/features/property_editor/color_curve_editor.dart';
import 'package:eyecandy/features/property_editor/property_editor_panel.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

void main() {
  testWidgets('circle properties expose both sliders and hard inputs', (
    tester,
  ) async {
    final catalog = _buildCatalog();
    final graph = catalog.createStarterGraph(name: 'Test');
    final circleNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'circle_node',
    );
    final controller = _createBoundController(graph);

    controller.selectNode(circleNode.id);
    await _pumpPropertyEditor(tester, controller: controller, height: 700);

    expect(_panelText('Radius'), findsOneWidget);
    expect(_panelText('Outline'), findsOneWidget);
    expect(_panelText('Width'), findsOneWidget);
    expect(_panelText('Height'), findsOneWidget);
    expect(_panelDescendant(find.byType(Slider)), findsNWidgets(4));
    expect(_panelDescendant(find.byType(TextFormField)), findsNWidgets(4));
  });

  testWidgets('mix node exposes compact dropdowns and a color picker dialog', (
    tester,
  ) async {
    final catalog = _buildCatalog();
    final graph = catalog.createStarterGraph(name: 'Test');
    final mixNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );
    final controller = _createBoundController(graph);

    controller.selectNode(mixNode.id);
    await _pumpPropertyEditor(tester, controller: controller, height: 700);

    expect(_panelText('Pick'), findsNWidgets(2));

    await tester.tap(_panelText('Pick').first);
    await tester.pumpAndSettle();

    expect(find.text('Pick color'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('curve demo node exposes the bezier curve editor', (
    tester,
  ) async {
    final catalog = _buildCatalog();
    final graph = catalog.createStarterGraph(name: 'Test');
    final curveNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'curve_demo_node',
    );
    final controller = _createBoundController(graph);

    controller.selectNode(curveNode.id);
    await _pumpPropertyEditor(tester, controller: controller);

    expect(find.byType(ColorBezierCurveEditor), findsOneWidget);
    expect(_panelText('Double-click to add a point'), findsOneWidget);
  });

  testWidgets('gradient map node exposes editable gradient fallback', (
    tester,
  ) async {
    final catalog = _buildCatalog();
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
    final controller = _createBoundController(graph);

    controller.selectNode(gradientNode.id);
    await _pumpPropertyEditor(tester, controller: controller);

    expect(_panelText('Add Stop'), findsOneWidget);
    expect(_panelDescendant(find.byType(Slider)), findsAtLeastNWidgets(1));
  });

  testWidgets('image node exposes output-size controls', (tester) async {
    final catalog = _buildCatalog();
    final imageNode = catalog.instantiateNode(
      definitionId: 'image_node',
      position: Vector2.zero(),
    );
    final graph = GraphDocument(
      id: 'image-output-size-graph',
      name: 'Image Output Size',
      nodes: [imageNode],
      links: const [],
    );
    final controller = _createBoundController(graph);

    controller.selectNode(imageNode.id);
    await _pumpPropertyEditor(tester, controller: controller);

    expect(_panelText('Output Size Mode'), findsOneWidget);
    expect(_panelText('Output Size'), findsOneWidget);
    expect(_panelText('Relative to parent'), findsOneWidget);
  });

  testWidgets('text node exposes text editors', (tester) async {
    final catalog = _buildCatalog();
    final textNode = catalog.instantiateNode(
      definitionId: 'text_node',
      position: Vector2.zero(),
    );
    final graph = GraphDocument(
      id: 'text-graph',
      name: 'Text',
      nodes: [textNode],
      links: const [],
    );
    final controller = _createBoundController(graph);

    controller.selectNode(textNode.id);
    await _pumpPropertyEditor(tester, controller: controller);

    expect(_panelText('Font Family'), findsOneWidget);
    expect(_panelText('Background Color'), findsOneWidget);
    expect(_panelText('Text Color'), findsOneWidget);
  });
}

MaterialGraphCatalog _buildCatalog() => MaterialGraphCatalog(IdFactory());

MaterialGraphController _createBoundController(GraphDocument graph) {
  final controller = MaterialGraphController.preview();
  addTearDown(controller.dispose);
  controller.bindGraph(graph: graph, onChanged: (_) {});
  return controller;
}

Future<void> _pumpPropertyEditor(
  WidgetTester tester, {
  required MaterialGraphController controller,
  double width = 360,
  double height = 760,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: PropertyEditorPanel(controller: controller),
        ),
      ),
    ),
  );
}

Finder _panelDescendant(Finder matching) {
  return find.descendant(
    of: find.byType(PropertyEditorPanel),
    matching: matching,
  );
}

Finder _panelText(String text) => _panelDescendant(find.text(text));
