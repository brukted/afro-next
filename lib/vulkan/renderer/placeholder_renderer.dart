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
  Future<void> dispose() async {}

  @override
  Future<Map<String, PreviewRenderTarget>> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) async {
    final plan = _planner.createPlan(graph);
    return {
      for (final pass in plan.passes)
        pass.nodeId: PreviewRenderTarget(
          id: pass.outputTarget.id,
          kind: PreviewRenderTargetKind.placeholder,
          label: dirtyNodeIds.contains(pass.nodeId) ? 'Dirty preview' : 'Ready',
          status: pass.isSupported
              ? PreviewRenderStatus.ready
              : PreviewRenderStatus.unsupported,
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

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {}
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
  Future<void> dispose() async {}

  @override
  Future<Map<String, PreviewRenderTarget>> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) async {
    final plan = _planner.createPlan(graph);
    return {
      for (final pass in plan.passes)
        pass.nodeId: PreviewRenderTarget(
          id: pass.outputTarget.id,
          kind: PreviewRenderTargetKind.placeholder,
          label: 'Preview',
          status: pass.isSupported
              ? PreviewRenderStatus.ready
              : PreviewRenderStatus.unsupported,
          diagnostics: <String>[
            'Shader: ${pass.shader?.assetId ?? 'Unassigned'}',
            'Target: ${pass.outputTarget.usage.name}',
            'Bindings: ${pass.descriptorBindings.length}',
            'Revision: $revision',
          ],
        ),
    };
  }

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {}
}
