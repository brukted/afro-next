import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../../vulkan/renderer/renderer_facade.dart';
import '../../../vulkan/resources/preview_render_target.dart';
import '../../graph/models/graph_models.dart';
import '../material_output_size.dart';
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
  int _activeRefreshToken = 0;

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

  void bindGraph(
    GraphDocument graph, {
    MaterialOutputSizeSettings graphOutputSizeSettings =
        const MaterialOutputSizeSettings(),
    MaterialOutputSizeValue sessionParentOutputSize =
        const MaterialOutputSizeValue.parentDefault(),
  }) {
    final previousGraphId = _compiledGraph?.graphId;
    final previousNodeIds =
        _compiledGraph?.topologicalNodeIds.toSet() ?? <String>{};
    final compiledGraph = _compiledGraph = _compiler.compile(
      graph,
      graphOutputSizeSettings: graphOutputSizeSettings,
      sessionParentOutputSize: sessionParentOutputSize,
    );
    unawaited(
      _refreshGraphPreviews(
        compiledGraph: compiledGraph,
        dirtyRootNodeIds: graph.nodes.map((node) => node.id),
        previousGraphId: previousGraphId,
        previousNodeIds: previousNodeIds,
      ),
    );
  }

  void updateGraph(
    GraphDocument graph, {
    MaterialOutputSizeSettings graphOutputSizeSettings =
        const MaterialOutputSizeSettings(),
    MaterialOutputSizeValue sessionParentOutputSize =
        const MaterialOutputSizeValue.parentDefault(),
    Iterable<String> dirtyRootNodeIds = const <String>[],
    bool refreshPreviews = true,
  }) {
    final compiledGraph = _compiledGraph = _compiler.compile(
      graph,
      graphOutputSizeSettings: graphOutputSizeSettings,
      sessionParentOutputSize: sessionParentOutputSize,
    );
    if (!refreshPreviews) {
      return;
    }

    unawaited(
      _refreshGraphPreviews(
        compiledGraph: compiledGraph,
        dirtyRootNodeIds: dirtyRootNodeIds,
      ),
    );
  }

  void clearGraph() {
    final previousGraphId = _compiledGraph?.graphId;
    final previousNodeIds =
        _compiledGraph?.topologicalNodeIds.toSet() ?? <String>{};
    _compiledGraph = null;
    _previews = <String, PreviewRenderTarget>{};
    _activeRefreshToken += 1;
    if (previousGraphId != null) {
      unawaited(
        _renderer.disposeGraph(
          graphId: previousGraphId,
          activeNodeIds: previousNodeIds,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _refreshPreviews({
    required MaterialCompiledGraph compiledGraph,
    required Iterable<String> dirtyRootNodeIds,
  }) async {
    final dirtyRoots = dirtyRootNodeIds.toSet();
    final dirtyNodeIds = dirtyRoots.isEmpty
        ? compiledGraph.topologicalNodeIds.toSet()
        : compiledGraph.expandDirtyNodes(dirtyRoots);
    _previewRevision += 1;
    final revision = _previewRevision;
    final refreshToken = ++_activeRefreshToken;
    _previews = _mergeRenderingTargets(
      current: _previews,
      graph: compiledGraph,
      dirtyNodeIds: dirtyNodeIds,
      revision: revision,
    );
    notifyListeners();
    final renderedPreviews = await _renderer.renderGraphPreviews(
      graph: compiledGraph,
      dirtyNodeIds: dirtyNodeIds,
      revision: revision,
    );
    if (_activeRefreshToken != refreshToken) {
      return;
    }
    if (_compiledGraph?.graphId != compiledGraph.graphId) {
      return;
    }
    _previews = renderedPreviews;
    notifyListeners();
  }

  Future<void> _refreshGraphPreviews({
    required MaterialCompiledGraph compiledGraph,
    required Iterable<String> dirtyRootNodeIds,
    String? previousGraphId,
    Set<String> previousNodeIds = const <String>{},
  }) async {
    if (previousGraphId != null && previousGraphId != compiledGraph.graphId) {
      await _renderer.disposeGraph(
        graphId: previousGraphId,
        activeNodeIds: previousNodeIds,
      );
    }
    await _renderer.disposeGraph(
      graphId: compiledGraph.graphId,
      activeNodeIds: compiledGraph.topologicalNodeIds.toSet(),
    );
    if (_compiledGraph?.graphId != compiledGraph.graphId) {
      return;
    }
    await _refreshPreviews(
      compiledGraph: compiledGraph,
      dirtyRootNodeIds: dirtyRootNodeIds,
    );
  }

  Map<String, PreviewRenderTarget> _mergeRenderingTargets({
    required Map<String, PreviewRenderTarget> current,
    required MaterialCompiledGraph graph,
    required Set<String> dirtyNodeIds,
    required int revision,
  }) {
    final next = <String, PreviewRenderTarget>{};
    for (final pass in graph.nodePasses) {
      final existing = current[pass.nodeId];
      if (!dirtyNodeIds.contains(pass.nodeId) && existing != null) {
        next[pass.nodeId] = existing;
        continue;
      }
      next[pass.nodeId] =
          (existing ??
                  const PreviewRenderTarget(
                    id: '',
                    kind: PreviewRenderTargetKind.placeholder,
                    label: 'Rendering preview',
                    diagnostics: <String>[],
                  ))
              .copyWith(
                id: existing?.id ?? pass.nodeId,
                kind: existing?.kind ?? PreviewRenderTargetKind.placeholder,
                label: 'Rendering preview',
                status: PreviewRenderStatus.rendering,
                diagnostics: <String>[
                  'Definition: ${pass.definitionId}',
                  'Extent: ${pass.resolvedOutputSize.width}x${pass.resolvedOutputSize.height}',
                  'Revision: $revision',
                ],
              );
    }
    return next;
  }
}
