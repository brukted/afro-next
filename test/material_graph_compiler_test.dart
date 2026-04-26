import 'package:afro/features/graph/models/graph_models.dart';
import 'package:afro/features/graph/models/graph_schema.dart';
import 'package:afro/features/math_graph/math_graph_catalog.dart';
import 'package:afro/features/math_graph/runtime/math_graph_compiler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import 'package:afro/features/material_graph/material_graph_catalog.dart';
import 'package:afro/features/material_graph/material_output_size.dart';
import 'package:afro/features/material_graph/runtime/material_execution_ir.dart';
import 'package:afro/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:afro/features/workspace/workspace_controller.dart';
import 'package:afro/shared/ids/id_factory.dart';

void main() {
  test('compiles a graph into topologically ordered fragment passes', () {
    final catalog = _buildCatalog();
    final graph = catalog.createStarterGraph(name: 'Test Graph');
    final compiled = _compileGraph(catalog, graph);
    final order = compiled.topologicalNodeIds;
    final solidColor = graph.nodes.firstWhere(
      (node) => node.definitionId == 'solid_color_node',
    );
    final circle = graph.nodes.firstWhere(
      (node) => node.definitionId == 'circle_node',
    );
    final mix = graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );
    final channelSelect = graph.nodes.firstWhere(
      (node) => node.definitionId == 'channel_select_node',
    );

    expect(
      order,
      containsAll(<String>[solidColor.id, circle.id, mix.id, channelSelect.id]),
    );
    expect(order.indexOf(solidColor.id), greaterThanOrEqualTo(0));
    expect(order.indexOf(circle.id), greaterThanOrEqualTo(0));
    expect(order.indexOf(mix.id), greaterThanOrEqualTo(0));
    expect(order.indexOf(channelSelect.id), greaterThanOrEqualTo(0));
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
      mixPass.parameterBindings.any(
        (binding) => binding.bindingKey == 'blendMode',
      ),
      isTrue,
    );
  });

  test('compiler preserves generated LUT textures and matrix parameters', () {
    final catalog = _buildCatalog();
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
        _connect(
          fromNode: levels,
          fromKey: '_output',
          toNode: curve,
          toKey: 'MainTex',
        ),
        _connect(
          fromNode: curve,
          fromKey: '_output',
          toNode: transform,
          toKey: 'MainTex',
        ),
      ],
    );

    final compiled = _compileGraph(catalog, graph);
    final curvePass = compiled.passForNode(curve.id)!;
    final transformPass = compiled.passForNode(transform.id)!;

    expect(curvePass.shaderAssetId, 'material/curve.frag');
    expect(curvePass.textureInputs.map((input) => input.bindingKey), [
      'MainTex',
      'CurveLUT',
    ]);
    expect(curvePass.textureInputs.first.isConnected, isTrue);
    expect(curvePass.textureInputs.last.isConnected, isFalse);
    expect(
      curvePass.textureInputs.last.valueType,
      GraphValueType.colorBezierCurve,
    );

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
    final catalog = _buildCatalog();
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

    final compiled = _compileGraph(catalog, graph);
    final imagePass = compiled.passForNode(image.id)!;
    final textPass = compiled.passForNode(text.id)!;
    final gradientPass = compiled.passForNode(gradientMap.id)!;

    expect(imagePass.textureInputs.single.bindingKey, 'MainTex');
    expect(
      imagePass.textureInputs.single.valueType,
      GraphValueType.workspaceResource,
    );
    expect(textPass.textureInputs.single.valueType, GraphValueType.textBlock);
    expect(
      gradientPass.textureInputs
          .firstWhere((input) => input.bindingKey == 'ColorLUT')
          .valueType,
      GraphValueType.gradient,
    );
    expect(
      gradientPass.textureInputs
          .firstWhere((input) => input.bindingKey == 'MainTex')
          .isConnected,
      isTrue,
    );
  });

  test('compiler resolves output size inheritance for graph and nodes', () {
    final catalog = _buildCatalog();
    final solidColor = catalog.instantiateNode(
      definitionId: 'solid_color_node',
      position: vmath.Vector2.zero(),
    );
    final blur = catalog.instantiateNode(
      definitionId: 'blur_node',
      position: vmath.Vector2(320, 0),
    );
    final graph = GraphDocument(
      id: 'size-graph',
      name: 'Size Graph',
      nodes: [
        _updateNodeOutputSize(solidColor),
        _updateNodeOutputMode(blur, MaterialOutputSizeMode.relativeToInput),
      ],
      links: [
        _connect(
          fromNode: solidColor,
          fromKey: '_output',
          toNode: blur,
          toKey: 'MainTex',
        ),
      ],
    );

    final compiled = _compileGraph(
      catalog,
      graph,
      graphOutputSizeSettings: const MaterialOutputSizeSettings(
        mode: MaterialOutputSizeMode.relativeToParent,
        value: MaterialOutputSizeValue(widthLog2: 1, heightLog2: 0),
      ),
      sessionParentOutputSize: const MaterialOutputSizeValue(
        widthLog2: 8,
        heightLog2: 8,
      ),
    );

    expect(compiled.resolvedGraphOutputSize.width, 512);
    expect(compiled.resolvedGraphOutputSize.height, 256);
    // 10,9 -> 1024x512
    expect(compiled.passForNode(solidColor.id)!.resolvedOutputSize.width, 1024);
    expect(compiled.passForNode(solidColor.id)!.resolvedOutputSize.height, 512);
    expect(compiled.passForNode(blur.id)!.resolvedOutputSize.width, 1024);
    expect(compiled.passForNode(blur.id)!.resolvedOutputSize.height, 512);
  });

  test('compiler respects graph absolute output size', () {
    final catalog = _buildCatalog();
    final solidColor = catalog.instantiateNode(
      definitionId: 'solid_color_node',
      position: vmath.Vector2.zero(),
    );
    final graph = GraphDocument(
      id: 'absolute-graph',
      name: 'Absolute Graph',
      nodes: [solidColor],
      links: const [],
    );

    final compiled = _compileGraph(
      catalog,
      graph,
      graphOutputSizeSettings: const MaterialOutputSizeSettings(
        mode: MaterialOutputSizeMode.absolute,
        value: MaterialOutputSizeValue(widthLog2: 10, heightLog2: 9),
      ),
    );

    expect(compiled.resolvedGraphOutputSize.width, 1024);
    expect(compiled.resolvedGraphOutputSize.height, 512);
    expect(compiled.passForNode(solidColor.id)!.resolvedOutputSize.width, 1024);
    expect(compiled.passForNode(solidColor.id)!.resolvedOutputSize.height, 512);
  });

  test(
    'compiler falls back to graph size for relative-to-input nodes without links',
    () {
      final catalog = _buildCatalog();
      final blur = _updateNodeOutputMode(
        catalog.instantiateNode(
          definitionId: 'blur_node',
          position: vmath.Vector2.zero(),
        ),
        MaterialOutputSizeMode.relativeToInput,
      );
      final graph = GraphDocument(
        id: 'fallback-graph',
        name: 'Fallback Graph',
        nodes: [blur],
        links: const [],
      );

      final compiled = _compileGraph(
        catalog,
        graph,
        graphOutputSizeSettings: const MaterialOutputSizeSettings(
          mode: MaterialOutputSizeMode.absolute,
          value: MaterialOutputSizeValue(widthLog2: 9, heightLog2: 8),
        ),
      );

      expect(compiled.passForNode(blur.id)!.resolvedOutputSize.width, 512);
      expect(compiled.passForNode(blur.id)!.resolvedOutputSize.height, 256);
    },
  );

  test('compiler applies relative deltas on inherited input sizes', () {
    final catalog = _buildCatalog();
    final source = _updateNodeOutputSize(
      catalog.instantiateNode(
        definitionId: 'solid_color_node',
        position: vmath.Vector2.zero(),
      ),
      size: const MaterialOutputSizeValue(widthLog2: 9, heightLog2: 9),
    );
    final blur = _updateNodeOutputSize(
      _updateNodeOutputMode(
        catalog.instantiateNode(
          definitionId: 'blur_node',
          position: vmath.Vector2(320, 0),
        ),
        MaterialOutputSizeMode.relativeToInput,
      ),
      size: const MaterialOutputSizeValue(widthLog2: 1, heightLog2: -1),
      updateMode: false,
    );
    final graph = GraphDocument(
      id: 'relative-delta-graph',
      name: 'Relative Delta Graph',
      nodes: [source, blur],
      links: [
        _connect(
          fromNode: source,
          fromKey: '_output',
          toNode: blur,
          toKey: 'MainTex',
        ),
      ],
    );

    final compiled = _compileGraph(catalog, graph);

    expect(compiled.passForNode(source.id)!.resolvedOutputSize.width, 512);
    expect(compiled.passForNode(source.id)!.resolvedOutputSize.height, 512);
    expect(compiled.passForNode(blur.id)!.resolvedOutputSize.width, 1024);
    expect(compiled.passForNode(blur.id)!.resolvedOutputSize.height, 256);
  });

  test('compiler resolves value socket bindings from material input nodes', () {
    final catalog = _buildCatalog();
    final input = _setFloatProperty(
      catalog.instantiateNode(
        definitionId: 'input_float_node',
        position: vmath.Vector2.zero(),
      ),
      'value',
      0.72,
    );
    final circle = catalog.instantiateNode(
      definitionId: 'circle_node',
      position: vmath.Vector2(320, 0),
    );
    final graph = GraphDocument(
      id: 'value-input-graph',
      name: 'Value Inputs',
      nodes: [input, circle],
      links: [
        _connect(
          fromNode: input,
          fromKey: '_output',
          toNode: circle,
          toKey: 'radius',
        ),
      ],
    );

    final compiled = _compileGraph(catalog, graph);
    final inputPass = compiled.passForNode(input.id)!;
    final circlePass = compiled.passForNode(circle.id)!;
    final radiusBinding = circlePass.parameterBindings.firstWhere(
      (binding) => binding.bindingKey == 'radius',
    );

    expect(inputPass.textureInputs, hasLength(1));
    expect(inputPass.textureInputs.single.bindingKey, 'MainTex');
    expect(inputPass.textureInputs.single.fallbackValue.floatValue, 0.72);
    expect(radiusBinding.valueType, GraphValueType.float);
    expect(radiusBinding.value.floatValue, 0.72);
  });

  test('compiler emits generated fragment programs for texel graph nodes', () {
    final catalog = _buildCatalog();
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview()
      ..createMathGraphAt(null)
      ..updateActiveMathGraph(_buildScalarSampleMathGraph('amount'));
    final mathGraphCompiler = MathGraphCompiler(catalog: MathGraphCatalog(IdFactory()));
    final texelNode = _setWorkspaceResourceProperty(
      catalog.instantiateNode(
        definitionId: 'texel_graph_node',
        position: vmath.Vector2.zero(),
      ),
      key: 'graph',
      value: workspaceController.openedResource!.id,
    );
    final graph = GraphDocument(
      id: 'texel-generated-graph',
      name: 'Texel Generated',
      nodes: [texelNode],
      links: const [],
    );

    final compiled = MaterialGraphCompiler(
      catalog: catalog,
      workspaceController: workspaceController,
      mathGraphCompiler: mathGraphCompiler,
    ).compile(graph);
    final texelPass = compiled.passForNode(texelNode.id)!;

    expect(texelPass.program?.kind, MaterialCompiledProgramKind.generatedFragment);
    expect(texelPass.textureInputs.map((input) => input.bindingKey), ['sampler_0']);
    expect(
      texelPass.parameterBindings.map((binding) => binding.bindingKey),
      ['in_amount'],
    );
    expect(texelPass.program?.source, contains('vec4 outColor;'));
    expect(texelPass.diagnostics, isEmpty);
  });

  test('compiler reports unsupported texel graph return types', () {
    final catalog = _buildCatalog();
    final workspaceController = WorkspaceController.preview()
      ..initializeForPreview()
      ..createMathGraphAt(null)
      ..updateActiveMathGraph(_buildFloat2MathGraph());
    final mathGraphCompiler = MathGraphCompiler(catalog: MathGraphCatalog(IdFactory()));
    final texelNode = _setWorkspaceResourceProperty(
      catalog.instantiateNode(
        definitionId: 'texel_graph_node',
        position: vmath.Vector2.zero(),
      ),
      key: 'graph',
      value: workspaceController.openedResource!.id,
    );
    final graph = GraphDocument(
      id: 'texel-invalid-graph',
      name: 'Texel Invalid',
      nodes: [texelNode],
      links: const [],
    );

    final compiled = MaterialGraphCompiler(
      catalog: catalog,
      workspaceController: workspaceController,
      mathGraphCompiler: mathGraphCompiler,
    ).compile(graph);
    final texelPass = compiled.passForNode(texelNode.id)!;

    expect(texelPass.program, isNull);
    expect(
      texelPass.diagnostics.join('\n'),
      contains('Texel Graph only supports math graphs returning float or float4.'),
    );
  });
}

MaterialGraphCatalog _buildCatalog() => MaterialGraphCatalog(IdFactory());

MaterialCompiledGraph _compileGraph(
  MaterialGraphCatalog catalog,
  GraphDocument graph, {
  MaterialOutputSizeSettings graphOutputSizeSettings =
      const MaterialOutputSizeSettings(),
  MaterialOutputSizeValue sessionParentOutputSize =
      const MaterialOutputSizeValue.parentDefault(),
}) {
  return MaterialGraphCompiler(catalog: catalog).compile(
    graph,
    graphOutputSizeSettings: graphOutputSizeSettings,
    sessionParentOutputSize: sessionParentOutputSize,
  );
}

GraphNodeDocument _updateNodeOutputSize(
  GraphNodeDocument node, {
  MaterialOutputSizeValue size = const MaterialOutputSizeValue(
    widthLog2: 10,
    heightLog2: 9,
  ),
  bool updateMode = true,
}) {
  return node.copyWith(
    properties: node.properties
        .map((property) {
          if (updateMode &&
              property.definitionKey == materialNodeOutputSizeModeKey) {
            return property.copyWith(
              value: GraphValueData.enumChoice(
                materialOutputSizeModeEnumValue(
                  MaterialOutputSizeMode.absolute,
                ),
              ),
            );
          }
          if (property.definitionKey == materialNodeOutputSizeValueKey) {
            return property.copyWith(
              value: GraphValueData.integer2(size.asInteger2),
            );
          }
          return property;
        })
        .toList(growable: false),
  );
}

GraphNodeDocument _updateNodeOutputMode(
  GraphNodeDocument node,
  MaterialOutputSizeMode mode,
) {
  return node.copyWith(
    properties: node.properties
        .map((property) {
          if (property.definitionKey == materialNodeOutputSizeModeKey) {
            return property.copyWith(
              value: GraphValueData.enumChoice(
                materialOutputSizeModeEnumValue(mode),
              ),
            );
          }
          return property;
        })
        .toList(growable: false),
  );
}

GraphNodeDocument _setFloatProperty(
  GraphNodeDocument node,
  String key,
  double value,
) {
  return node.copyWith(
    properties: node.properties
        .map(
          (property) => property.definitionKey == key
              ? property.copyWith(value: GraphValueData.float(value))
              : property,
        )
        .toList(growable: false),
  );
}

GraphNodeDocument _setWorkspaceResourceProperty(
  GraphNodeDocument node, {
  required String key,
  required String value,
}) {
  return node.copyWith(
    properties: node.properties
        .map(
          (property) => property.definitionKey == key
              ? property.copyWith(value: GraphValueData.workspaceResource(value))
              : property,
        )
        .toList(growable: false),
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
  final configuredAmount = amount.copyWith(
    properties: amount.properties
        .map(
          (property) => property.definitionKey == 'identifier'
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

GraphDocument _buildFloat2MathGraph() {
  final catalog = MathGraphCatalog(IdFactory());
  final pos = catalog.instantiateNode(
    definitionId: 'builtin_pos_node',
    position: vmath.Vector2.zero(),
  );
  final output = catalog.instantiateNode(
    definitionId: 'output_float2_node',
    position: vmath.Vector2(240, 0),
  );
  return GraphDocument(
    id: 'math-float2',
    name: 'Float2 Output',
    nodes: [pos, output],
    links: [
      _connect(fromNode: pos, fromKey: '_output', toNode: output, toKey: 'value'),
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
