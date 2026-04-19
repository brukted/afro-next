import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vmath;

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

  test('compiler preserves generated LUT textures and matrix parameters', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final levels = catalog.instantiateNode(
      definitionId: 'levels_node',
      position: vmath.Vector2.zero(),
    );
    final curve = catalog.instantiateNode(
      definitionId: 'curve_node',
      position: vmath.Vector2(320, 0),
    );
    final transform = catalog.instantiateNode(
      definitionId: 'transform_node',
      position: vmath.Vector2(640, 0),
    );
    final graph = GraphDocument(
      id: 'graph-1',
      name: 'Expanded Graph',
      nodes: [levels, curve, transform],
      links: [
        _connect(fromNode: levels, fromKey: '_output', toNode: curve, toKey: 'MainTex'),
        _connect(fromNode: curve, fromKey: '_output', toNode: transform, toKey: 'MainTex'),
      ],
    );

    final compiled = MaterialGraphCompiler(catalog: catalog).compile(graph);
    final curvePass = compiled.passForNode(curve.id)!;
    final transformPass = compiled.passForNode(transform.id)!;

    expect(curvePass.shaderAssetId, 'material/curve.frag');
    expect(curvePass.textureInputs.map((input) => input.bindingKey), [
      'MainTex',
      'CurveLUT',
    ]);
    expect(curvePass.textureInputs.first.isConnected, isTrue);
    expect(curvePass.textureInputs.last.isConnected, isFalse);
    expect(curvePass.textureInputs.last.valueType, GraphValueType.colorBezierCurve);

    final rotationBinding = transformPass.parameterBindings.firstWhere(
      (binding) => binding.bindingKey == 'rotation',
    );
    expect(rotationBinding.valueType, GraphValueType.float3x3);
    expect(rotationBinding.value.asFloat3x3(), [
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
      0.0,
      0.0,
      1.0,
    ]);
  });

  test('compiler preserves workspace assets and text-generated textures', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final image = catalog.instantiateNode(
      definitionId: 'image_node',
      position: vmath.Vector2.zero(),
    );
    final text = catalog.instantiateNode(
      definitionId: 'text_node',
      position: vmath.Vector2(320, 0),
    );
    final gradientMap = catalog.instantiateNode(
      definitionId: 'gradientmap_node',
      position: vmath.Vector2(640, 0),
    );
    final graph = GraphDocument(
      id: 'asset-graph',
      name: 'Assets',
      nodes: [image, text, gradientMap],
      links: [
        _connect(
          fromNode: image,
          fromKey: '_output',
          toNode: gradientMap,
          toKey: 'MainTex',
        ),
      ],
    );

    final compiled = MaterialGraphCompiler(catalog: catalog).compile(graph);
    final imagePass = compiled.passForNode(image.id)!;
    final textPass = compiled.passForNode(text.id)!;
    final gradientPass = compiled.passForNode(gradientMap.id)!;

    expect(imagePass.textureInputs.single.bindingKey, 'MainTex');
    expect(imagePass.textureInputs.single.valueType, GraphValueType.workspaceResource);
    expect(textPass.textureInputs.single.valueType, GraphValueType.textBlock);
    expect(
      gradientPass.textureInputs.firstWhere((input) => input.bindingKey == 'ColorLUT').valueType,
      GraphValueType.gradient,
    );
    expect(
      gradientPass.textureInputs.firstWhere((input) => input.bindingKey == 'MainTex').isConnected,
      isTrue,
    );
  });
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
