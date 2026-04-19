import 'package:eyecandy/features/graph/models/graph_models.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
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

    final mixNode = graph.nodes.firstWhere((node) => node.definitionId == 'mix_node');
    final channelSelectNode = graph.nodes.firstWhere(
      (node) => node.definitionId == 'channel_select_node',
    );

    final mixPass = plan.passForNode(mixNode.id)!;
    final outputPass = plan.passForNode(channelSelectNode.id)!;

    expect(mixPass.isSupported, isTrue);
    expect(mixPass.shader?.assetId, 'material/blend.frag');
    expect(mixPass.descriptorBindings.first.kind, VulkanDescriptorBindingKind.uniformBuffer);
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

  test('planner supports expanded fullscreen nodes and generated LUT bindings', () {
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
        _connect(fromNode: levels, fromKey: '_output', toNode: curve, toKey: 'MainTex'),
        _connect(fromNode: curve, fromKey: '_output', toNode: transform, toKey: 'MainTex'),
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
    expect(
      curvePass.descriptorBindings.where(
        (binding) => binding.kind == VulkanDescriptorBindingKind.sampledImage,
      ),
      hasLength(2),
    );

    expect(transformPass.isSupported, isTrue);
    expect(transformPass.shader?.assetId, 'material/transform.frag');
    expect(transformPass.outputTarget.usage, VulkanImageTargetUsage.finalOutput);
    expect(plan.finalOutputTargetId, transformPass.outputTarget.id);
  });

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
