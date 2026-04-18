import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/material_graph_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy property keys normalize during material graph binding', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final controller = MaterialGraphController.preview();
    final legacyGraph = _withLegacyKeys(catalog.createStarterGraph(name: 'Legacy'));
    GraphDocument? normalizedFromCallback;

    controller.bindGraph(
      graph: legacyGraph,
      onChanged: (graph) => normalizedFromCallback = graph,
    );

    final mixNode = controller.graph.nodes.firstWhere((node) => node.definitionId == 'mix_node');
    final bindings = controller.boundPropertiesForNode(mixNode);

    expect(
      mixNode.properties.map((property) => property.definitionKey),
      ['Foreground', 'Background', 'Mask', 'blendMode', 'alphaMode', 'alpha', '_output'],
    );
    expect(bindings.map((binding) => binding.definition.key), [
      'Foreground',
      'Background',
      'Mask',
      'blendMode',
      'alphaMode',
      'alpha',
      '_output',
    ]);
    expect(normalizedFromCallback, isNotNull);
  });
}

GraphDocument _withLegacyKeys(GraphDocument graph) {
  const aliases = {
    '_output': 'output',
    'Foreground': 'foreground',
    'Background': 'background',
    'Mask': 'mask',
    'channel_red': 'channelRed',
    'channel_green': 'channelGreen',
    'channel_blue': 'channelBlue',
    'channel_alpha': 'channelAlpha',
  };

  return graph.copyWith(
    nodes: graph.nodes
        .map(
          (node) => node.copyWith(
            properties: node.properties
                .map(
                  (property) => property.copyWith(
                    definitionKey: aliases[property.definitionKey] ?? property.definitionKey,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );
}
