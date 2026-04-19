import '../../features/material_graph/runtime/material_execution_ir.dart';
import 'material_backend_models.dart';
import 'material_node_preview_support.dart';

class VulkanMaterialBackendPlanner {
  const VulkanMaterialBackendPlanner();

  VulkanMaterialBackendPlan createPlan(MaterialCompiledGraph graph) {
    final passes = graph.nodePasses
        .map((pass) => _createPassPlan(graph: graph, pass: pass))
        .toList(growable: false);

    return VulkanMaterialBackendPlan(
      graphId: graph.graphId,
      passes: passes,
      passesByNodeId: {for (final pass in passes) pass.nodeId: pass},
      previewTargetIdsByNodeId: {
        for (final pass in passes) pass.nodeId: pass.outputTarget.id,
      },
      finalOutputTargetId: _firstFinalOutputTargetId(passes),
    );
  }

  VulkanMaterialPassPlan _createPassPlan({
    required MaterialCompiledGraph graph,
    required MaterialCompiledNodePass pass,
  }) {
    final previewSupport = MaterialNodePreviewSupportRegistry.lookup(pass);
    final isSupported = previewSupport != null;
    final outputUsage = pass.nodeId == graph.defaultOutputNodeId
        ? VulkanImageTargetUsage.finalOutput
        : VulkanImageTargetUsage.preview;

    return VulkanMaterialPassPlan(
      nodeId: pass.nodeId,
      shader: pass.shaderAssetId == null
          ? null
          : VulkanShaderAsset(
              assetId: pass.shaderAssetId!,
              stage: pass.executionKind,
            ),
      descriptorBindings: [
        const VulkanDescriptorBindingSpec(
          set: 0,
          binding: 0,
          name: 'MaterialPassUniforms',
          kind: VulkanDescriptorBindingKind.uniformBuffer,
        ),
        const VulkanDescriptorBindingSpec(
          set: 0,
          binding: 1,
          name: 'LinearClampSampler',
          kind: VulkanDescriptorBindingKind.sampler,
        ),
        ...List<VulkanDescriptorBindingSpec>.generate(
          pass.textureInputs.length,
          (index) => VulkanDescriptorBindingSpec(
            set: 0,
            binding: index + 2,
            name: pass.textureInputs[index].bindingKey,
            kind: VulkanDescriptorBindingKind.sampledImage,
          ),
          growable: false,
        ),
      ],
      outputTarget: VulkanImageTargetPlan(
        id: '${pass.nodeId}/color',
        nodeId: pass.nodeId,
        usage: outputUsage,
      ),
      pipelineCacheKey: VulkanMaterialPipelineCacheKey(
        shaderAssetId: pass.shaderAssetId ?? 'unsupported:${pass.definitionId}',
        executionKind: pass.executionKind,
        sampledInputCount: pass.textureInputs.length,
      ),
      isSupported: isSupported,
      resolvedOutputSize: pass.resolvedOutputSize,
    );
  }

  String? _firstFinalOutputTargetId(List<VulkanMaterialPassPlan> passes) {
    for (final pass in passes) {
      if (pass.outputTarget.usage == VulkanImageTargetUsage.finalOutput) {
        return pass.outputTarget.id;
      }
    }

    return null;
  }
}
