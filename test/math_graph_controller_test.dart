import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/math_graph/math_graph_catalog.dart';
import 'package:afro/features/math_graph/math_graph_controller.dart';
import 'package:afro/features/math_graph/runtime/math_graph_compiler.dart';
import 'package:afro/features/workspace/workspace_controller.dart';
import 'package:afro/shared/ids/id_factory.dart';
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

  test(
    'invalid graphs surface compiler diagnostics while remaining editable',
    () {
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
        controller.diagnostics.any(
          (diagnostic) => diagnostic.code == 'invalid_output_count',
        ),
        isTrue,
      );
      expect(controller.compiledFunction, isNull);
    },
  );

  test('bindGraph expands subgraph inputs from the referenced math graph', () {
    final harness = _buildSubgraphHarness(
      mathGraph: _buildSubgraphChildGraph('amount'),
    );
    addTearDown(harness.controller.dispose);
    final subgraphNode = harness.controller.graph.nodes.firstWhere(
      (node) => node.definitionId == mathSubgraphNodeDefinitionId,
    );

    final propertyKeys = harness.controller
        .boundPropertiesForNode(subgraphNode)
        .map((binding) => binding.definition.key)
        .toList(growable: false);

    expect(
      propertyKeys,
      containsAll(<String>['graph', 'in_amount', '_output']),
    );
  });

  test(
    'rebind removes stale subgraph properties and links after signature changes',
    () {
      final harness = _buildSubgraphHarness(
        mathGraph: _buildSubgraphChildGraph('amount'),
      );
      addTearDown(harness.controller.dispose);
      final subgraphNode = harness.controller.graph.nodes.firstWhere(
        (node) => node.definitionId == mathSubgraphNodeDefinitionId,
      );
      final inputNode = harness.controller.graphInputNodes.firstWhere(
        (node) => node.definitionId == 'get_float1_node',
      );
      final subgraphInputPropertyId = harness.controller
          .nodeById(subgraphNode.id)!
          .propertyByDefinitionKey('in_amount')!
          .id;

      harness.controller.handleSocketTap(
        nodeId: inputNode.id,
        propertyId: inputNode.propertyByDefinitionKey('_output')!.id,
      );
      harness.controller.handleSocketTap(
        nodeId: subgraphNode.id,
        propertyId: subgraphInputPropertyId,
      );
      expect(harness.controller.graph.links, isNotEmpty);

      harness.workspaceController.openResource(harness.childResourceId);
      harness.workspaceController.updateActiveMathGraph(_buildValidGraph());
      harness.workspaceController.openResource(
        harness.workspaceController.workspace.rootFolderId,
      );
      harness.controller.bindGraph(
        graph: harness.controller.graph,
        onChanged: (_) {},
      );

      final reboundSubgraph = harness.controller.graph.nodes.firstWhere(
        (node) => node.id == subgraphNode.id,
      );
      expect(reboundSubgraph.propertyByDefinitionKey('in_amount'), isNull);
      expect(
        reboundSubgraph.propertyByDefinitionKey('in_inputValue'),
        isNotNull,
      );
      expect(
        harness.controller.graph.links.any(
          (link) => link.toPropertyId == subgraphInputPropertyId,
        ),
        isFalse,
      );
    },
  );
}

class _MathSubgraphHarness {
  const _MathSubgraphHarness({
    required this.controller,
    required this.workspaceController,
    required this.childResourceId,
  });

  final MathGraphController controller;
  final WorkspaceController workspaceController;
  final String childResourceId;
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
              ? property.copyWith(
                  value: GraphValueData.stringValue('inputValue'),
                )
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

_MathSubgraphHarness _buildSubgraphHarness({required GraphDocument mathGraph}) {
  final workspaceController = WorkspaceController.preview()
    ..initializeForPreview()
    ..createMathGraphAt(null)
    ..updateActiveMathGraph(mathGraph);
  final childResourceId = workspaceController.openedResource!.id;
  workspaceController.openResource(workspaceController.workspace.rootFolderId);
  final catalog = MathGraphCatalog(IdFactory());
  final compiler = MathGraphCompiler(
    catalog: catalog,
    workspaceController: workspaceController,
  );
  final controller = MathGraphController(
    idFactory: IdFactory(),
    catalog: catalog,
    compiler: compiler,
    workspaceController: workspaceController,
  );
  final subgraphNode = catalog.instantiateNode(
    definitionId: mathSubgraphNodeDefinitionId,
    position: Vector2.zero(),
  );
  final configuredSubgraph = subgraphNode.copyWith(
    properties: subgraphNode.properties
        .map(
          (property) =>
              property.definitionKey == mathSubgraphResourcePropertyKey
              ? property.copyWith(
                  value: GraphValueData.workspaceResource(childResourceId),
                )
              : property,
        )
        .toList(growable: false),
  );
  final input = catalog.instantiateNode(
    definitionId: 'get_float1_node',
    position: Vector2(-220, 0),
  );
  final configuredInput = input.copyWith(
    properties: input.properties
        .map(
          (property) => property.definitionKey == 'identifier'
              ? property.copyWith(value: GraphValueData.stringValue('driver'))
              : property,
        )
        .toList(growable: false),
  );
  controller.bindGraph(
    graph: GraphDocument(
      id: 'math-subgraph-parent',
      name: 'Math Subgraph Parent',
      nodes: [configuredInput, configuredSubgraph],
      links: const [],
    ),
    onChanged: (_) {},
  );
  return _MathSubgraphHarness(
    controller: controller,
    workspaceController: workspaceController,
    childResourceId: childResourceId,
  );
}

GraphDocument _buildSubgraphChildGraph(String identifier) {
  final catalog = MathGraphCatalog(IdFactory());
  final input = catalog.instantiateNode(
    definitionId: 'get_float1_node',
    position: Vector2.zero(),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float_node',
    position: Vector2(240, 0),
  );
  final configuredInput = input.copyWith(
    properties: input.properties
        .map(
          (property) => property.definitionKey == 'identifier'
              ? property.copyWith(value: GraphValueData.stringValue(identifier))
              : property,
        )
        .toList(growable: false),
  );
  return GraphDocument(
    id: 'subgraph-child-$identifier',
    name: 'Subgraph Child $identifier',
    nodes: [configuredInput, output],
    links: [
      GraphLinkDocument(
        id: '$identifier-link',
        fromNodeId: configuredInput.id,
        fromPropertyId: configuredInput.propertyByDefinitionKey('_output')!.id,
        toNodeId: output.id,
        toPropertyId: output.propertyByDefinitionKey('value')!.id,
      ),
    ],
  );
}
