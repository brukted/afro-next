import '../../features/material_graph/models/material_graph_models.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../resources/preview_render_target.dart';

abstract interface class RendererFacade {
  Future<RendererBootstrapState> bootstrap();

  PreviewRenderTarget renderNodePreview({
    required GraphNodeDefinition definition,
    required GraphNodeInstance node,
    required int revision,
  });
}
