import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/features/material_graph/runtime/material_graph_compiler.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:eyecandy/vulkan/material_backend/material_backend_models.dart';
import 'package:eyecandy/vulkan/material_backend/material_backend_planner.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
