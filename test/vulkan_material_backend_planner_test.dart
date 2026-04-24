import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/math_graph/math_graph_catalog.dart';
import 'package:eyecandy/features/math_graph/runtime/math_graph_compiler.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:eyecandy/features/workspace/workspace_controller.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:eyecandy/vulkan/material_backend/material_backend_models.dart';
import 'package:eyecandy/vulkan/material_backend/material_backend_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vmath;

void main() {
  test('builds a fragment-first backend plan from a compiled graph', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Backend Plan');
    final compiled = MaterialGraphCompiler(catalog: catalog).compile(graph);
    final plan = const VulkanMaterialBackendPlanner().createPlan(compiled);

    final mixNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'mix_node',
    );
    final channelSelectNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'channel_select_node',
    );

    final mixPass = plan.passForNode(mixNode.id)!;
    final outputPass = plan.passForNode(channelSelectNode.id)!;

    expect(mixPass.isSupported, isTrue);
    expect(mixPass.shader?.assetId, 'material/blend.frag');
    expect(mixPass.resolvedOutputSize.extentLabel, '512x512');
    expect(
      mixPass.descriptorBindings.first.kind,
      VulkanDescriptorBindingKind.uniformBuffer,
    );
    expect(
      mixPass.descriptorBindings.where(
        (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
      ),
      hasLength(3),
    );
    expect(outputPass.outputTarget.usage, VulkanImageTargetUsage.finalOutput);
    expect(plan.finalOutputTargetId, outputPass.outputTarget.id);
    expect(plan.previewTargetIdsByNodeId[mixNode.id], mixPass.outputTarget.id);
  });

  test(
    'planner supports expanded fullscreen nodes and generated LUT bindings',
    () {
      final catalog = MaterialGraphCatalog(IdFactory());
      final levels = catalog.instantiateNode(
        definitionId: 'levels_node',
        position: vmath.Vector2.zero(),
      );
      final curve = catalog.instantiateNode(
        definitionId: 'curve_node',
        position: vmath.Vector2(300, 0),
      );
      final transform = catalog.instantiateNode(
        definitionId: 'transform_node',
        position: vmath.Vector2(600, 0),
      );
      final graph = GraphDocument(
        id: 'graph-1',
        name: 'Expanded Plan',
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

      final compiled = MaterialGraphCompiler(catalog: catalog).compile(graph);
      final plan = const VulkanMaterialBackendPlanner().createPlan(compiled);

      final levelsPass = plan.passForNode(levels.id)!;
      final curvePass = plan.passForNode(curve.id)!;
      final transformPass = plan.passForNode(transform.id)!;

      expect(levelsPass.isSupported, isTrue);
      expect(levelsPass.shader?.assetId, 'material/levels.frag');
      expect(
        levelsPass.descriptorBindings.where(
          (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
        ),
        hasLength(1),
      );

      expect(curvePass.isSupported, isTrue);
      expect(curvePass.shader?.assetId, 'material/curve.frag');
      expect(curvePass.resolvedOutputSize.extentLabel, '512x512');
      expect(
        curvePass.descriptorBindings.where(
          (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
        ),
        hasLength(2),
      );

      expect(transformPass.isSupported, isTrue);
      expect(transformPass.shader?.assetId, 'material/transform.frag');
      expect(
        transformPass.outputTarget.usage,
        VulkanImageTargetUsage.finalOutput,
      );
      expect(plan.finalOutputTargetId, transformPass.outputTarget.id);
    },
  );

  test('planner supports asset-backed image svg and text nodes', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final image = catalog.instantiateNode(
      definitionId: 'image_node',
      position: vmath.Vector2.zero(),
    );
    final svg = catalog.instantiateNode(
      definitionId: 'svg_node',
      position: vmath.Vector2(240, 0),
    );
    final text = catalog.instantiateNode(
      definitionId: 'text_node',
      position: vmath.Vector2(480, 0),
    );
    final graph = GraphDocument(
      id: 'asset-plan',
      name: 'Asset Plan',
      nodes: [image, svg, text],
      links: const [],
    );

    final compiled = MaterialGraphCompiler(catalog: catalog).compile(graph);
    final plan = const VulkanMaterialBackendPlanner().createPlan(compiled);

    final imagePass = plan.passForNode(image.id)!;
    final svgPass = plan.passForNode(svg.id)!;
    final textPass = plan.passForNode(text.id)!;

    expect(imagePass.isSupported, isTrue);
    expect(svgPass.isSupported, isTrue);
    expect(textPass.isSupported, isTrue);
    expect(imagePass.resolvedOutputSize.extentLabel, '512x512');
    expect(imagePass.shader?.assetId, 'material/image-basic.frag');
    expect(
      imagePass.descriptorBindings.where(
        (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
      ),
      hasLength(1),
    );
    expect(
      svgPass.descriptorBindings.where(
        (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
      ),
      hasLength(1),
    );
    expect(
      textPass.descriptorBindings.where(
        (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
      ),
      hasLength(1),
    );
  });

  test('planner carries generated texel graph programs through the backend plan', () {
    final catalog = MaterialGraphCatalog(IdFactory());
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
      id: 'texel-plan',
      name: 'Texel Plan',
      nodes: [texelNode],
      links: const [],
    );

    final compiled = MaterialGraphCompiler(
      catalog: catalog,
      workspaceController: workspaceController,
      mathGraphCompiler: mathGraphCompiler,
    ).compile(graph);
    final plan = const VulkanMaterialBackendPlanner().createPlan(compiled);
    final texelPass = plan.passForNode(texelNode.id)!;

    expect(texelPass.isSupported, isTrue);
    expect(texelPass.shader?.kind, VulkanShaderKind.generated);
    expect(texelPass.shader?.source, contains('sampler2D(sampler_0, LinearClampSampler)'));
    expect(texelPass.pipelineCacheKey.shaderKey, contains('texel_graph:'));
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
    id: 'math-plan-$scalarIdentifier',
    name: 'Planner Sample',
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
