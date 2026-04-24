import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_runtime.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:eyecandy/vulkan/renderer/placeholder_renderer.dart';
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
