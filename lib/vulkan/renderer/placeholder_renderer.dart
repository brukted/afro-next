import '../../features/material_graph/runtime/material_execution_ir.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../material_backend/material_backend_models.dart';
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
    return _buildPlaceholderTargets(
      plan: _planner.createPlan(graph),
      dirtyNodeIds: dirtyNodeIds,
      revision: revision,
      labelBuilder: (pass, isDirty) => isDirty ? 'Dirty preview' : 'Ready',
      diagnosticsBuilder: (pass, revision) => <String>[
        'Shader: ${pass.shader?.assetId ?? 'Unassigned'}',
        'Stage: ${pass.shader?.stage.name ?? 'unsupported'}',
        'Bindings: ${pass.descriptorBindings.length}',
        'Target: ${pass.outputTarget.usage.name}',
        pass.resolvedOutputSize.extentDiagnostic,
        'Cache key: ${pass.pipelineCacheKey.shaderAssetId}',
        'Supported: ${pass.isSupported}',
        'Revision: $revision',
      ],
    );
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
    return _buildPlaceholderTargets(
      plan: _planner.createPlan(graph),
      dirtyNodeIds: dirtyNodeIds,
      revision: revision,
      labelBuilder: (_, _) => 'Preview',
      diagnosticsBuilder: (pass, revision) => <String>[
        'Shader: ${pass.shader?.assetId ?? 'Unassigned'}',
        'Target: ${pass.outputTarget.usage.name}',
        'Bindings: ${pass.descriptorBindings.length}',
        pass.resolvedOutputSize.extentDiagnostic,
        'Revision: $revision',
      ],
    );
  }

  @override
  Future<void> disposeGraph({
    required String graphId,
    required Set<String> activeNodeIds,
  }) async {}
}

Map<String, PreviewRenderTarget> _buildPlaceholderTargets({
  required VulkanMaterialBackendPlan plan,
  required Set<String> dirtyNodeIds,
  required int revision,
  required String Function(VulkanMaterialPassPlan pass, bool isDirty)
  labelBuilder,
  required List<String> Function(VulkanMaterialPassPlan pass, int revision)
  diagnosticsBuilder,
}) {
  return {
    for (final pass in plan.passes)
      pass.nodeId: PreviewRenderTarget(
        id: pass.outputTarget.id,
        kind: PreviewRenderTargetKind.placeholder,
        label: labelBuilder(pass, dirtyNodeIds.contains(pass.nodeId)),
        status: pass.isSupported
            ? PreviewRenderStatus.ready
            : PreviewRenderStatus.unsupported,
        diagnostics: diagnosticsBuilder(pass, revision),
      ),
  };
}
