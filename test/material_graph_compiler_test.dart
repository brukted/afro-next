import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';

void main() {
  test('compiles a graph into topologically ordered fragment passes', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final compiler = MaterialGraphCompiler(catalog: catalog);

    final compiled = compiler.compile(graph);
    final order = compiled.topologicalNodeIds;
    final solidColor = graph.nodes.firstWhere(
      (node) => node.definitionId == 'solid_color_node',
    );
    final circle = graph.nodes.firstWhere(
      (node) => node.definitionId == 'circle_node',
    );
    final mix = graph.nodes.firstWhere((node) => node.definitionId == 'mix_node');
    final channelSelect = graph.nodes.firstWhere(
      (node) => node.definitionId == 'channel_select_node',
    );

    expect(order.indexOf(solidColor.id), lessThan(order.indexOf(mix.id)));
    expect(order.indexOf(circle.id), lessThan(order.indexOf(mix.id)));
    expect(order.indexOf(mix.id), lessThan(order.indexOf(channelSelect.id)));

    final mixPass = compiled.passForNode(mix.id)!;
    expect(mixPass.shaderAssetId, 'material/blend.frag');
    expect(mixPass.textureInputs, hasLength(3));
    expect(
      mixPass.textureInputs.where((input) => input.isConnected),
      hasLength(2),
    );
    expect(
      mixPass.parameterBindings.any((binding) => binding.bindingKey == 'blendMode'),
      isTrue,
    );
  });
}
