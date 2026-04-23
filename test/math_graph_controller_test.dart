import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/math_graph/math_graph_catalog.dart';
import 'package:eyecandy/features/math_graph/math_graph_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('binding a valid math graph compiles immediately', () {
    final controller = MathGraphController.preview();
    addTearDown(controller.dispose);

    controller.bindGraph(graph: _buildValidGraph(), onChanged: (_) {});

    expect(controller.hasErrors, isFalse);
    expect(controller.compiledFunction, isNotNull);
    expect(controller.compiledFunction!.source, contains('float sampleValue('));
  });

  test('updating a property recompiles and persists through onChanged', () {
    final controller = MathGraphController.preview();
    addTearDown(controller.dispose);
    GraphDocument? latestGraph;
    final graph = _buildConstantGraph();

    controller.bindGraph(
      graph: graph,
      onChanged: (updatedGraph) => latestGraph = updatedGraph,
    );

    final node = controller.graph.nodes.firstWhere(
      (entry) => entry.definitionId == 'float_constant_node',
    );
    final property = node.propertyByDefinitionKey('value')!;
    controller.updatePropertyValue(
      nodeId: node.id,
      propertyId: property.id,
      value: GraphValueData.float(2.5),
    );

    expect(latestGraph, isNotNull);
    expect(controller.hasErrors, isFalse);
    expect(controller.compiledFunction!.source, contains('float t0 = 2.5;'));
  });

  test('invalid graphs surface compiler diagnostics while remaining editable', () {
    final controller = MathGraphController.preview();
    addTearDown(controller.dispose);
    final invalidGraph = GraphDocument(
      id: 'invalid-graph',
      name: 'invalidGraph',
      nodes: [
        MathGraphCatalog(IdFactory()).instantiateNode(
          definitionId: 'add_float_node',
          position: Vector2.zero(),
        ),
      ],
      links: const [],
    );

    controller.bindGraph(graph: invalidGraph, onChanged: (_) {});

    expect(controller.hasErrors, isTrue);
    expect(
      controller.diagnostics.any((diagnostic) => diagnostic.code == 'invalid_output_count'),
      isTrue,
    );
    expect(controller.compiledFunction, isNull);
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

GraphDocument _buildConstantGraph() {
  final catalog = MathGraphCatalog(IdFactory());
  final constant = catalog.instantiateNode(
    definitionId: 'float_constant_node',
    position: Vector2.zero(),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float_node',
    position: Vector2(240, 0),
  );
  return GraphDocument(
    id: 'constant-graph',
    name: 'constantValue',
    nodes: [constant, output],
    links: [
      GraphLinkDocument(
        id: 'constant-link',
        fromNodeId: constant.id,
        fromPropertyId: constant.propertyByDefinitionKey('_output')!.id,
        toNodeId: output.id,
        toPropertyId: output.propertyByDefinitionKey('value')!.id,
      ),
    ],
  );
}
