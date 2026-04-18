import '../../features/graph/models/graph_bindings.dart';
import '../../features/graph/models/graph_models.dart';
import '../../features/material_graph/material_node_definition.dart';
import '../bootstrap/vulkan_bootstrap.dart';
import '../resources/preview_render_target.dart';

abstract interface class RendererFacade {
  Future<RendererBootstrapState> bootstrap();

  PreviewRenderTarget renderNodePreview({
    required MaterialNodeDefinition definition,
    required GraphNodeDocument node,
    required List<GraphPropertyBinding> bindings,
    required int revision,
    required bool isDirty,
  });
}
