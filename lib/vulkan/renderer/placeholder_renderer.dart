import 'package:flutter/material.dart';

import '../../features/material_graph/runtime/material_execution_ir.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../material_backend/material_backend_planner.dart';
import '../resources/preview_render_target.dart';
import 'renderer_facade.dart';

class PlaceholderVulkanRendererFacade implements RendererFacade {
  const PlaceholderVulkanRendererFacade({
    required this.bootstrapper,
    VulkanMaterialBackendPlanner planner = const VulkanMaterialBackendPlanner(),
  }) : _planner = planner;

  final VulkanBootstrapper bootstrapper;
  final VulkanMaterialBackendPlanner _planner;

  @override
  Future<RendererBootstrapState> bootstrap() => bootstrapper.bootstrap();

  @override
  Map<String, PreviewRenderTarget> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) {
    final plan = _planner.createPlan(graph);
    return {
      for (final pass in plan.passes)
        pass.nodeId: PreviewRenderTarget(
          id: pass.outputTarget.id,
          kind: PreviewRenderTargetKind.placeholder,
          label: dirtyNodeIds.contains(pass.nodeId) ? 'Dirty preview' : 'Ready',
          accentColor: _accentColorForNode(graph, pass.nodeId),
          diagnostics: <String>[
            'Shader: ${pass.shader?.assetId ?? 'Unassigned'}',
            'Stage: ${pass.shader?.stage.name ?? 'unsupported'}',
            'Bindings: ${pass.descriptorBindings.length}',
            'Target: ${pass.outputTarget.usage.name}',
            'Cache key: ${pass.pipelineCacheKey.shaderAssetId}',
            'Supported: ${pass.isSupported}',
            'Revision: $revision',
          ],
        ),
    };
  }
}

class PreviewOnlyRendererFacade implements RendererFacade {
  const PreviewOnlyRendererFacade({
    VulkanMaterialBackendPlanner planner = const VulkanMaterialBackendPlanner(),
  }) : _planner = planner;

  final VulkanMaterialBackendPlanner _planner;

  @override
  Future<RendererBootstrapState> bootstrap() async {
    return const RendererBootstrapState.preview();
  }

  @override
  Map<String, PreviewRenderTarget> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) {
    final plan = _planner.createPlan(graph);
    return {
      for (final pass in plan.passes)
        pass.nodeId: PreviewRenderTarget(
          id: pass.outputTarget.id,
          kind: PreviewRenderTargetKind.placeholder,
          label: 'Preview',
          accentColor: _accentColorForNode(graph, pass.nodeId),
          diagnostics: <String>[
            'Shader: ${pass.shader?.assetId ?? 'Unassigned'}',
            'Target: ${pass.outputTarget.usage.name}',
            'Bindings: ${pass.descriptorBindings.length}',
            'Revision: $revision',
          ],
        ),
    };
  }
}

Color _accentColorForNode(MaterialCompiledGraph graph, String nodeId) {
  final definitionId = graph.nodePasses
      .firstWhere((pass) => pass.nodeId == nodeId)
      .definitionId;
  return _accentColorForDefinition(definitionId);
}

Color _accentColorForDefinition(String definitionId) {
  switch (definitionId) {
    case 'solid_color_node':
      return const Color(0xFF3DD6B0);
    case 'mix_node':
      return const Color(0xFF7D67FF);
    case 'channel_select_node':
      return const Color(0xFFFFB053);
    case 'circle_node':
      return const Color(0xFFF06C8F);
    case 'curve_demo_node':
      return const Color(0xFF8FA8FF);
    default:
      return const Color(0xFF7D67FF);
  }
}
