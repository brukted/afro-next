import '../../features/material_graph/runtime/material_execution_ir.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../resources/preview_render_target.dart';

abstract interface class RendererFacade {
  Future<RendererBootstrapState> bootstrap();

  Map<String, PreviewRenderTarget> renderGraphPreviews({
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  });
}
