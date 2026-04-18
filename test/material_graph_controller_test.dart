import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';

void main() {
  test('duplicates a node with copied properties and offset position', () {
    final controller = _buildController();
    final source = controller.graph.nodes.first;

    controller.duplicateNode(source.id);

    final duplicate = controller.selectedNode!;
    expect(controller.graph.nodes.length, 6);
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

  test('deletes a node and all links attached to it', () {
    final controller = _buildController();
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

MaterialGraphController _buildController() {
  final controller = MaterialGraphController.preview();
  final catalog = MaterialGraphCatalog(IdFactory());
  controller.bindGraph(
    graph: catalog.createStarterGraph(name: 'Test Graph'),
    onChanged: (_) {},
  );
  return controller;
}
