import 'package:afro/app/theme/app_theme.dart';
import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/math_graph/math_graph_catalog.dart';
import 'package:afro/features/math_graph/math_graph_controller.dart';
import 'package:afro/features/math_graph/math_graph_inspector_panel.dart';
import 'package:afro/features/math_graph/math_graph_panel.dart';
import 'package:afro/features/material_graph/material_graph_controller.dart';
import 'package:afro/features/workspace/models/workspace_models.dart';
import 'package:afro/features/workspace/workspace_controller.dart';
import 'package:afro/features/workspace/workspace_screen.dart';
import 'package:afro/shared/ids/id_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  testWidgets('math inspector shows generated GLSL for a valid graph', (tester) async {
    final controller = MathGraphController.preview();
    addTearDown(controller.dispose);
    final graph = _buildValidGraph();
    controller.bindGraph(graph: graph, onChanged: (_) {});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 760,
            child: MathGraphInspectorPanel(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Generated GLSL'), findsOneWidget);
    expect(find.textContaining('sampleValue -> float'), findsOneWidget);
    expect(find.textContaining('float sampleValue('), findsOneWidget);
  });

  testWidgets('workspace screen routes math resources to math editor and inspector', (
    tester,
  ) async {
    final workspaceController = WorkspaceController.preview()..initializeForPreview();
    final materialGraphController = MaterialGraphController.preview();
    final mathGraphController = MathGraphController.preview();
    addTearDown(workspaceController.dispose);
    addTearDown(materialGraphController.dispose);
    addTearDown(mathGraphController.dispose);

    final mathResource = workspaceController.workspace.resources.firstWhere(
      (entry) => entry.kind == WorkspaceResourceKind.mathGraph,
    );
    workspaceController.openResource(mathResource.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: WorkspaceScreen(
          workspaceController: workspaceController,
          materialGraphController: materialGraphController,
          mathGraphController: mathGraphController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MathGraphPanel), findsOneWidget);
    expect(find.byType(MathGraphInspectorPanel), findsOneWidget);
    expect(find.text('Math Editor'), findsOneWidget);
    expect(find.text('Math Inspector'), findsOneWidget);
  });
}

GraphDocument _buildValidGraph() {
  final catalog = MathGraphCatalog(IdFactory());
  final input = catalog.instantiateNode(
    definitionId: 'get_float1_node',
    position: Vector2.zero(),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float_node',
    position: Vector2(240, 0),
  );
  final updatedInput = input.copyWith(
    properties: input.properties
        .map(
          (property) => property.definitionKey == 'identifier'
              ? property.copyWith(value: GraphValueData.stringValue('inputValue'))
              : property,
        )
        .toList(growable: false),
  );
  return GraphDocument(
    id: 'valid-graph',
    name: 'sampleValue',
    nodes: [updatedInput, output],
    links: [
      GraphLinkDocument(
        id: 'link',
        fromNodeId: updatedInput.id,
        fromPropertyId: updatedInput.propertyByDefinitionKey('_output')!.id,
        toNodeId: output.id,
        toPropertyId: output.propertyByDefinitionKey('value')!.id,
      ),
    ],
  );
}
