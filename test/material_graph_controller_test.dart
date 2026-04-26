import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/graph/models/graph_schema.dart';
import 'package:afro/features/math_graph/math_graph_catalog.dart';
import 'package:afro/features/math_graph/runtime/math_graph_compiler.dart';
import 'package:afro/features/material_graph/material_graph_catalog.dart';
import 'package:afro/features/material_graph/material_graph_controller.dart';
import 'package:afro/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:afro/features/material_graph/runtime/material_graph_runtime.dart';
import 'package:afro/features/workspace/workspace_controller.dart';
import 'package:afro/shared/ids/id_factory.dart';
import 'package:afro/vulkan/renderer/placeholder_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vmath;

void main() {
  test('renames a node in the bound graph', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final source = controller.graph.nodes.first;

    controller.renameNode(source.id, 'Primary Color');

    expect(controller.nodeById(source.id)!.name, 'Primary Color');
  });

  test('persists input unit metadata on graph input nodes', () {
    final controller = _buildSingleNodeController(definitionId: 'input_float2_node');
    addTearDown(controller.dispose);
    final inputNode = controller.graph.nodes.single;

    controller.updateInputUnit(inputNode.id, GraphValueUnit.position);

    expect(
      controller.inputUnitForNode(controller.graph.nodes.single),
      GraphValueUnit.position,
    );
    expect(controller.graph.nodes.single.inputUnitId, GraphValueUnit.position.name);
  });

  test('exposes a property as a new input node and links it', () {
    final controller = _buildSingleNodeController(definitionId: 'circle_node');
    addTearDown(controller.dispose);
    final node = controller.graph.nodes.single;
    final radiusPropertyId = node.propertyByDefinitionKey('radius')!.id;
    final expectedValue = node.propertyByDefinitionKey('radius')!.value.floatValue;

    controller.exposePropertyAsInput(nodeId: node.id, propertyId: radiusPropertyId);

    final inputNode = controller.graph.nodes.firstWhere(
      (entry) => entry.definitionId == 'input_float_node',
    );
    final inputValue = inputNode.propertyByDefinitionKey('value')!.value.floatValue;
    final link = controller.graph.links.singleWhere(
      (entry) => entry.toPropertyId == radiusPropertyId,
    );

    expect(controller.graph.nodes, hasLength(2));
    expect(inputNode.name, 'Radius Input');
    expect(inputValue, expectedValue);
    expect(link.fromNodeId, inputNode.id);
    expect(controller.selectedNodeId, inputNode.id);
  });

  test('exposed material inputs inherit soft range metadata', () {
    final controller = _buildSingleNodeController(definitionId: 'circle_node');
    addTearDown(controller.dispose);
    final node = controller.graph.nodes.single;
    final radiusPropertyId = node.propertyByDefinitionKey('radius')!.id;

    controller.exposePropertyAsInput(nodeId: node.id, propertyId: radiusPropertyId);

    final inputNode = controller.graph.nodes.firstWhere(
      (entry) => entry.definitionId == 'input_float_node',
    );
    expect(
      inputNode.propertyByDefinitionKey('hasMin')!.value.boolValue,
      isTrue,
    );
    expect(
      inputNode.propertyByDefinitionKey('min')!.value.floatValue,
      0.0,
    );
    expect(
      inputNode.propertyByDefinitionKey('hasMax')!.value.boolValue,
      isTrue,
    );
    expect(
      inputNode.propertyByDefinitionKey('max')!.value.floatValue,
      1.0,
    );
  });

  test('duplicates a node with copied properties and offset position', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final source = controller.graph.nodes.first;

    controller.duplicateNode(source.id);

    final duplicate = controller.selectedNode!;
    expect(controller.graph.nodes.length, 5);
    expect(duplicate.id, isNot(source.id));
    expect(duplicate.definitionId, source.definitionId);
    expect(duplicate.name, startsWith(source.name));
    expect(duplicate.position.x, moreOrLessEquals(source.position.x + 40));
    expect(duplicate.position.y, moreOrLessEquals(source.position.y + 32));
    expect(duplicate.properties, hasLength(source.properties.length));
    expect(
      duplicate.properties.map((property) => property.id).toSet(),
      isNot(containsAll(source.properties.map((property) => property.id))),
    );
  });

  test('disconnects all links touching a node without removing the node', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final mixNode = controller.graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );

    controller.disconnectNode(mixNode.id);

    expect(controller.graph.nodes.any((node) => node.id == mixNode.id), isTrue);
    expect(
      controller.graph.links.any(
        (link) => link.fromNodeId == mixNode.id || link.toNodeId == mixNode.id,
      ),
      isFalse,
    );
  });

  test('disconnects every link attached to a connected output socket', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final solidColor = controller.graph.nodes.firstWhere(
      (node) => node.definitionId == 'solid_color_node',
    );
    final outputPropertyId = controller.graph.links
        .firstWhere((link) => link.fromNodeId == solidColor.id)
        .fromPropertyId;

    controller.handleSocketTap(
      nodeId: solidColor.id,
      propertyId: outputPropertyId,
    );
    expect(controller.pendingConnection?.propertyId, outputPropertyId);

    controller.disconnectSocket(
      nodeId: solidColor.id,
      propertyId: outputPropertyId,
    );

    expect(
      controller.graph.links.any(
        (link) =>
            link.fromNodeId == solidColor.id &&
            link.fromPropertyId == outputPropertyId,
      ),
      isFalse,
    );
    expect(controller.pendingConnection, isNull);
  });

  test('deletes a node and all links attached to it', () {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final mixNode = controller.graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );
    controller.selectNode(mixNode.id);

    controller.deleteNode(mixNode.id);

    expect(
      controller.graph.nodes.any((node) => node.id == mixNode.id),
      isFalse,
    );
    expect(
      controller.graph.links.any(
        (link) => link.fromNodeId == mixNode.id || link.toNodeId == mixNode.id,
      ),
      isFalse,
    );
    expect(controller.selectedNodeId, isNull);
  });

  test('bindGraph expands texel graph inputs from the referenced math graph', () {
    final harness = _buildTexelHarness(mathGraph: _buildScalarSampleMathGraph('amount'));
    addTearDown(harness.controller.dispose);
    final texelNode = harness.controller.graph.nodes.single;

    final propertyKeys = harness.controller
        .boundPropertiesForNode(texelNode)
        .map((binding) => binding.definition.key)
        .toList(growable: false);

    expect(propertyKeys, containsAll(<String>['graph', 'in_amount', 'sampler_0', '_output']));
  });

  test('rebind removes stale texel graph properties and links after signature changes', () {
    final harness = _buildTexelHarness(mathGraph: _buildScalarSampleMathGraph('amount'));
    addTearDown(harness.controller.dispose);
    final texelNode = harness.controller.graph.nodes.single;
    final amountPropertyId = harness.controller
        .nodeById(texelNode.id)!
        .propertyByDefinitionKey('in_amount')!
        .id;

    harness.controller.exposePropertyAsInput(
      nodeId: texelNode.id,
      propertyId: amountPropertyId,
    );
    expect(harness.controller.graph.links, isNotEmpty);

    harness.workspaceController.updateActiveMathGraph(
      _buildColorSampleMathGraph(),
    );
    harness.controller.bindGraph(graph: harness.controller.graph, onChanged: (_) {});

    final reboundTexel = harness.controller.graph.nodes.firstWhere(
      (node) => node.id == texelNode.id,
    );
    expect(reboundTexel.propertyByDefinitionKey('in_amount'), isNull);
    expect(reboundTexel.propertyByDefinitionKey('sampler_0'), isNotNull);
    expect(
      harness.controller.graph.links.any(
        (link) => link.toPropertyId == amountPropertyId,
      ),
      isFalse,
    );
  });
}

class _TexelHarness {
  const _TexelHarness({
    required this.controller,
    required this.workspaceController,
  });

  final MaterialGraphController controller;
  final WorkspaceController workspaceController;
}

MaterialGraphController _buildSingleNodeController({
  required String definitionId,
}) {
  final idFactory = IdFactory();
  final catalog = MaterialGraphCatalog(idFactory);
  final controller = MaterialGraphController(
    idFactory: idFactory,
    catalog: catalog,
    runtime: MaterialGraphRuntime(
      compiler: MaterialGraphCompiler(catalog: catalog),
      renderer: const PreviewOnlyRendererFacade(),
    ),
  );
  final node = catalog.instantiateNode(
    definitionId: definitionId,
    position: vmath.Vector2.zero(),
  );
  controller.bindGraph(
    graph: GraphDocument(
      id: idFactory.next(),
      name: 'Single Node',
      nodes: [node],
      links: const [],
    ),
    onChanged: (_) {},
  );
  return controller;
}

MaterialGraphController _buildController() {
  final controller = MaterialGraphController.preview();
  final catalog = MaterialGraphCatalog(IdFactory());
  controller.bindGraph(
    graph: catalog.createStarterGraph(name: 'Test Graph'),
    onChanged: (_) {},
  );
  return controller;
}

_TexelHarness _buildTexelHarness({required GraphDocument mathGraph}) {
  final idFactory = IdFactory();
  final materialCatalog = MaterialGraphCatalog(idFactory);
  final workspaceController = WorkspaceController.preview()
    ..initializeForPreview()
    ..createMathGraphAt(null)
    ..updateActiveMathGraph(mathGraph);
  final mathGraphCompiler = MathGraphCompiler(catalog: MathGraphCatalog(IdFactory()));
  final controller = MaterialGraphController(
    idFactory: idFactory,
    catalog: materialCatalog,
    workspaceController: workspaceController,
    mathGraphCompiler: mathGraphCompiler,
    runtime: MaterialGraphRuntime(
      compiler: MaterialGraphCompiler(
        catalog: materialCatalog,
        workspaceController: workspaceController,
        mathGraphCompiler: mathGraphCompiler,
      ),
      renderer: const PreviewOnlyRendererFacade(),
    ),
  );
  final texelNode = materialCatalog.instantiateNode(
    definitionId: 'texel_graph_node',
    position: vmath.Vector2.zero(),
  );
  final resourceId = workspaceController.openedResource!.id;
  final configuredNode = texelNode.copyWith(
    properties: texelNode.properties
        .map(
          (property) => property.definitionKey == 'graph'
              ? property.copyWith(
                  value: GraphValueData.workspaceResource(resourceId),
                )
              : property,
        )
        .toList(growable: false),
  );
  controller.bindGraph(
    graph: GraphDocument(
      id: 'texel-graph',
      name: 'Texel Graph',
      nodes: [configuredNode],
      links: const [],
    ),
    onChanged: (_) {},
  );
  return _TexelHarness(
    controller: controller,
    workspaceController: workspaceController,
  );
}

GraphDocument _buildScalarSampleMathGraph(String scalarIdentifier) {
  final catalog = MathGraphCatalog(IdFactory());
  final pos = catalog.instantiateNode(
    definitionId: 'builtin_pos_node',
    position: vmath.Vector2.zero(),
  );
  final sample = catalog.instantiateNode(
    definitionId: 'sample_color_node',
    position: vmath.Vector2(200, 0),
  );
  final amount = catalog.instantiateNode(
    definitionId: 'get_float1_node',
    position: vmath.Vector2(200, 180),
  );
  final multiply = catalog.instantiateNode(
    definitionId: 'scalar_multiply_float4_node',
    position: vmath.Vector2(420, 80),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float4_node',
    position: vmath.Vector2(650, 80),
  );
  final amountProperty = amount.propertyByDefinitionKey('identifier')!;
  final configuredAmount = amount.copyWith(
    properties: amount.properties
        .map(
          (property) => property.id == amountProperty.id
              ? property.copyWith(
                  value: GraphValueData.stringValue(scalarIdentifier),
                )
              : property,
        )
        .toList(growable: false),
  );
  return GraphDocument(
    id: 'math-sample-$scalarIdentifier',
    name: 'Scalar Sample',
    nodes: [pos, sample, configuredAmount, multiply, output],
    links: [
      _connect(fromNode: pos, fromKey: '_output', toNode: sample, toKey: 'uv'),
      _connect(fromNode: sample, fromKey: '_output', toNode: multiply, toKey: 'a'),
      _connect(
        fromNode: configuredAmount,
        fromKey: '_output',
        toNode: multiply,
        toKey: 'b',
      ),
      _connect(fromNode: multiply, fromKey: '_output', toNode: output, toKey: 'value'),
    ],
  );
}

GraphDocument _buildColorSampleMathGraph() {
  final catalog = MathGraphCatalog(IdFactory());
  final pos = catalog.instantiateNode(
    definitionId: 'builtin_pos_node',
    position: vmath.Vector2.zero(),
  );
  final sample = catalog.instantiateNode(
    definitionId: 'sample_color_node',
    position: vmath.Vector2(220, 0),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float4_node',
    position: vmath.Vector2(420, 0),
  );
  return GraphDocument(
    id: 'math-color-sample',
    name: 'Color Sample',
    nodes: [pos, sample, output],
    links: [
      _connect(fromNode: pos, fromKey: '_output', toNode: sample, toKey: 'uv'),
      _connect(fromNode: sample, fromKey: '_output', toNode: output, toKey: 'value'),
    ],
  );
}

GraphLinkDocument _connect({
  required GraphNodeDocument fromNode,
  required String fromKey,
  required GraphNodeDocument toNode,
  required String toKey,
}) {
  return GraphLinkDocument(
    id: '${fromNode.id}:$fromKey->$toKey',
    fromNodeId: fromNode.id,
    fromPropertyId: fromNode.propertyByDefinitionKey(fromKey)!.id,
    toNodeId: toNode.id,
    toPropertyId: toNode.propertyByDefinitionKey(toKey)!.id,
  );
}
