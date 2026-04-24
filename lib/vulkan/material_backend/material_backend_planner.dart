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
    final isSupported =
        previewSupport != null && pass.program != null && pass.diagnostics.isEmpty;
    final outputUsage = pass.nodeId == graph.defaultOutputNodeId
        ? VulkanImageTargetUsage.finalOutput
        : VulkanImageTargetUsage.preview;
    final shader = switch (pass.program?.kind) {
      MaterialCompiledProgramKind.asset when pass.program?.assetId != null =>
        VulkanShaderAsset.asset(
          assetId: pass.program!.assetId!,
          stage: pass.executionKind,
          entryPoint: pass.program!.entryPoint,
        ),
      MaterialCompiledProgramKind.generatedFragment when pass.program?.source != null =>
        VulkanShaderAsset.generated(
          source: pass.program!.source!,
          cacheKey: pass.program!.cacheKey,
          stage: pass.executionKind,
          entryPoint: pass.program!.entryPoint,
        ),
      _ => null,
    };

    return VulkanMaterialPassPlan(
      nodeId: pass.nodeId,
      shader: shader,
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
        shaderKey: shader?.cacheKey ?? 'unsupported:${pass.definitionId}',
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
