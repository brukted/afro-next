import 'package:eyecandy/app/theme/app_theme.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/features/property_editor/property_editor_panel.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('circle properties expose both sliders and hard inputs', (
    tester,
  ) async {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final graph = catalog.createStarterGraph(name: 'Test');
    final circleNode = graph.nodes.firstWhere((node) => node.definitionId == 'circle_node');

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
    final mixNode = graph.nodes.firstWhere((node) => node.definitionId == 'mix_node');

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
}
