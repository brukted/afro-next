import 'package:flutter/foundation.dart';

import '../../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../../vulkan/renderer/renderer_facade.dart';
import '../../../vulkan/resources/preview_render_target.dart';
import '../../graph/models/graph_models.dart';
import 'material_execution_ir.dart';
import 'material_graph_compiler.dart';

class MaterialGraphRuntime extends ChangeNotifier {
  MaterialGraphRuntime({
    required MaterialGraphCompiler compiler,
    required RendererFacade renderer,
  }) : _compiler = compiler,
       _renderer = renderer;

  final MaterialGraphCompiler _compiler;
  final RendererFacade _renderer;

  RendererBootstrapState _rendererState =
      const RendererBootstrapState.preview();
  MaterialCompiledGraph? _compiledGraph;
  Map<String, PreviewRenderTarget> _previews = <String, PreviewRenderTarget>{};
  bool _initialized = false;
  int _previewRevision = 0;

  bool get isInitialized => _initialized;

  RendererBootstrapState get rendererState => _rendererState;

  MaterialCompiledGraph? get compiledGraph => _compiledGraph;

  PreviewRenderTarget? previewForNode(String nodeId) => _previews[nodeId];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _rendererState = await _renderer.bootstrap();
    _initialized = true;
    notifyListeners();
  }

  void bindGraph(GraphDocument graph) {
    _compiledGraph = _compiler.compile(graph);
    _refreshPreviews(
      dirtyRootNodeIds: graph.nodes.map((node) => node.id),
    );
  }

  void updateGraph(
    GraphDocument graph, {
    Iterable<String> dirtyRootNodeIds = const <String>[],
    bool refreshPreviews = true,
  }) {
    if (!refreshPreviews) {
      return;
    }

    _compiledGraph = _compiler.compile(graph);
    _refreshPreviews(dirtyRootNodeIds: dirtyRootNodeIds);
  }

  void clearGraph() {
    _compiledGraph = null;
    _previews = <String, PreviewRenderTarget>{};
    notifyListeners();
  }

  void _refreshPreviews({
    required Iterable<String> dirtyRootNodeIds,
  }) {
    final compiledGraph = _compiledGraph;
    if (compiledGraph == null) {
      _previews = <String, PreviewRenderTarget>{};
      notifyListeners();
      return;
    }

    final dirtyRoots = dirtyRootNodeIds.toSet();
    final dirtyNodeIds = dirtyRoots.isEmpty
        ? compiledGraph.topologicalNodeIds.toSet()
        : compiledGraph.expandDirtyNodes(dirtyRoots);
    _previewRevision += 1;
    _previews = _renderer.renderGraphPreviews(
      graph: compiledGraph,
      dirtyNodeIds: dirtyNodeIds,
      revision: _previewRevision,
    );
    notifyListeners();
  }
}
