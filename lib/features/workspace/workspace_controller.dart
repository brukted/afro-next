import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../services/filesystem/app_file_picker.dart';
import '../../services/logging/app_logger.dart';
import '../../services/preferences/app_preferences.dart';
import '../../shared/ids/id_factory.dart';
import '../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../vulkan/renderer/placeholder_renderer.dart';
import '../../vulkan/renderer/renderer_facade.dart';
import '../../vulkan/resources/preview_render_target.dart';
import '../material_graph/material_graph_catalog.dart';
import '../material_graph/models/material_graph_models.dart';

class PendingSocketConnection {
  const PendingSocketConnection({
    required this.nodeId,
    required this.propertyId,
    required this.direction,
  });

  final String nodeId;
  final String propertyId;
  final GraphSocketDirection direction;
}

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required IdFactory idFactory,
    required RendererFacade renderer,
    required AppPreferences preferences,
    required AppFilePicker filePicker,
    required AppLogger logger,
  }) : _idFactory = idFactory,
       _renderer = renderer,
       _preferences = preferences,
       _filePicker = filePicker,
       _logger = logger,
       _catalog = MaterialGraphCatalog(idFactory);

  factory WorkspaceController.preview() {
    final idFactory = IdFactory();
    return WorkspaceController(
      idFactory: idFactory,
      renderer: const PreviewOnlyRendererFacade(),
      preferences: AppPreferences.memory(),
      filePicker: const AppFilePicker.noop(),
      logger: AppLogger.memory(),
    );
  }

  final IdFactory _idFactory;
  final RendererFacade _renderer;
  final AppPreferences _preferences;
  final AppFilePicker _filePicker;
  final AppLogger _logger;
  final MaterialGraphCatalog _catalog;

  WorkspaceDocument? _workspace;
  String? _activeGraphId;
  String? _selectedNodeId;
  PendingSocketConnection? _pendingConnection;
  RendererBootstrapState _rendererState =
      const RendererBootstrapState.preview();
  final Map<String, PreviewRenderTarget> _previews =
      <String, PreviewRenderTarget>{};
  bool _initialized = false;
  int _previewRevision = 0;

  bool get isInitialized => _initialized;

  RendererBootstrapState get rendererState => _rendererState;

  WorkspaceLayoutPreferences get layoutPreferences =>
      _preferences.loadWorkspaceLayout();

  List<String> get recentFiles => _preferences.loadRecentFiles();

  List<GraphNodeDefinition> get nodeDefinitions => _catalog.definitions;

  WorkspaceDocument get workspace => _workspace!;

  String? get activeGraphId => _activeGraphId;

  String? get selectedNodeId => _selectedNodeId;

  PendingSocketConnection? get pendingConnection => _pendingConnection;

  MaterialGraphDocument get activeGraph {
    return workspace.graphs.firstWhere((graph) => graph.id == _activeGraphId);
  }

  GraphNodeInstance? get selectedNode {
    if (_selectedNodeId == null || _workspace == null) {
      return null;
    }

    return activeGraph.nodes.firstWhereOrNull(
      (node) => node.id == _selectedNodeId,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _rendererState = await _renderer.bootstrap();
    _workspace = _catalog.createInitialWorkspace();
    _activeGraphId = workspace.graphs.first.id;
    _initialized = true;

    _refreshPreviews();
    _logger.info(
      'Workspace initialized with ${activeGraph.nodes.length} nodes.',
    );
    notifyListeners();
  }

  void initializeForPreview() {
    if (_initialized) {
      return;
    }

    _rendererState = const RendererBootstrapState.preview();
    _workspace = _catalog.createInitialWorkspace();
    _activeGraphId = workspace.graphs.first.id;
    _initialized = true;
    _refreshPreviews();
  }

  Future<void> openWorkspaceFile() async {
    final path = await _filePicker.openWorkspaceFile();
    if (path == null) {
      return;
    }

    await _preferences.rememberRecentFile(path);
    _logger.info('Selected workspace file: $path');
    notifyListeners();
  }

  Future<void> saveWorkspaceFile() async {
    final path = await _filePicker.saveWorkspaceFile();
    if (path == null) {
      return;
    }

    await _preferences.rememberRecentFile(path);
    _logger.info('Selected export path: $path');
    notifyListeners();
  }

  Future<void> saveLayout({
    required double leftPaneWidth,
    required double inspectorWidth,
  }) {
    return _preferences.saveWorkspaceLayout(
      WorkspaceLayoutPreferences(
        leftPaneWidth: leftPaneWidth,
        inspectorWidth: inspectorWidth,
      ),
    );
  }

  void selectGraph(String graphId) {
    if (_activeGraphId == graphId) {
      return;
    }

    _activeGraphId = graphId;
    _selectedNodeId = null;
    _pendingConnection = null;
    _refreshPreviews();
    notifyListeners();
  }

  void selectNode(String? nodeId) {
    if (_selectedNodeId == nodeId) {
      return;
    }

    _selectedNodeId = nodeId;
    notifyListeners();
  }

  void addNode(String definitionId) {
    final matchingNodeCount = activeGraph.nodes
        .where((node) => node.definitionId == definitionId)
        .length;

    final node = _catalog.instantiateNode(
      definitionId: definitionId,
      position: Offset(
        180 + (matchingNodeCount * 48),
        140 + (matchingNodeCount * 36),
      ),
      sequence: matchingNodeCount + 1,
    );

    _replaceActiveGraph(
      activeGraph.copyWith(nodes: [...activeGraph.nodes, node]),
    );
    _selectedNodeId = node.id;
    _refreshPreviews();
    notifyListeners();
  }

  void moveNode(String nodeId, Offset delta) {
    final node = activeGraph.nodes.firstWhere((entry) => entry.id == nodeId);
    _replaceNode(
      node.copyWith(position: node.position + delta),
      refreshPreviews: false,
    );
    notifyListeners();
  }

  void handleSocketTap({required String nodeId, required String propertyId}) {
    final node = activeGraph.nodes.firstWhere((entry) => entry.id == nodeId);
    final definition = definitionForNode(node);
    final property = node.propertyById(propertyId)!;
    final propertyDefinition = definition.properties.firstWhere(
      (entry) => entry.key == property.definitionKey,
    );
    final direction = propertyDefinition.socketDirection;
    if (direction == null) {
      return;
    }

    if (_pendingConnection == null) {
      if (direction == GraphSocketDirection.output) {
        _pendingConnection = PendingSocketConnection(
          nodeId: nodeId,
          propertyId: propertyId,
          direction: direction,
        );
        notifyListeners();
      }
      return;
    }

    final pendingConnection = _pendingConnection!;
    if (pendingConnection.propertyId == propertyId) {
      _pendingConnection = null;
      notifyListeners();
      return;
    }

    if (pendingConnection.direction == direction) {
      if (direction == GraphSocketDirection.output) {
        _pendingConnection = PendingSocketConnection(
          nodeId: nodeId,
          propertyId: propertyId,
          direction: direction,
        );
        notifyListeners();
      }
      return;
    }

    if (direction == GraphSocketDirection.input) {
      _connectProperties(
        fromNodeId: pendingConnection.nodeId,
        fromPropertyId: pendingConnection.propertyId,
        toNodeId: nodeId,
        toPropertyId: propertyId,
      );
      return;
    }

    _connectProperties(
      fromNodeId: nodeId,
      fromPropertyId: propertyId,
      toNodeId: pendingConnection.nodeId,
      toPropertyId: pendingConnection.propertyId,
    );
  }

  void cancelPendingConnection() {
    if (_pendingConnection == null) {
      return;
    }

    _pendingConnection = null;
    notifyListeners();
  }

  void removeLink(String linkId) {
    _replaceActiveGraph(
      activeGraph.copyWith(
        links: activeGraph.links
            .where((link) => link.id != linkId)
            .toList(growable: false),
      ),
    );
    _refreshPreviews();
    notifyListeners();
  }

  void updateScalarProperty({
    required String nodeId,
    required String propertyId,
    required double value,
  }) {
    _updatePropertyValue(nodeId: nodeId, propertyId: propertyId, value: value);
  }

  void updateEnumProperty({
    required String nodeId,
    required String propertyId,
    required int value,
  }) {
    _updatePropertyValue(nodeId: nodeId, propertyId: propertyId, value: value);
  }

  void updateColorProperty({
    required String nodeId,
    required String propertyId,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  }) {
    final node = activeGraph.nodes.firstWhere((entry) => entry.id == nodeId);
    final current = node.propertyById(propertyId)!.value as Color;
    final updatedColor = Color.from(
      alpha: (alpha ?? current.a),
      red: (red ?? current.r),
      green: (green ?? current.g),
      blue: (blue ?? current.b),
    );

    _updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: updatedColor,
    );
  }

  GraphNodeDefinition definitionForNode(GraphNodeInstance node) {
    return _catalog.definitionById(node.definitionId);
  }

  PreviewRenderTarget? previewForNode(String nodeId) {
    return _previews[nodeId];
  }

  List<GraphNodePropertyView> boundPropertiesForNode(GraphNodeInstance node) {
    return node.bindProperties(definitionForNode(node));
  }

  String labelForProperty({
    required String nodeId,
    required String propertyId,
  }) {
    final node = activeGraph.nodes.firstWhere((entry) => entry.id == nodeId);
    final property = node.propertyById(propertyId)!;
    final definition = definitionForNode(node);
    return definition.propertyDefinition(property.definitionKey).label;
  }

  GraphNodeInstance? nodeForProperty(String propertyId) {
    return activeGraph.nodes.firstWhereOrNull(
      (node) => node.propertyById(propertyId) != null,
    );
  }

  void _connectProperties({
    required String fromNodeId,
    required String fromPropertyId,
    required String toNodeId,
    required String toPropertyId,
  }) {
    final filteredLinks = activeGraph.links
        .where((link) {
          if (link.toPropertyId == toPropertyId) {
            return false;
          }

          final duplicatesSameDirection =
              link.fromPropertyId == fromPropertyId &&
              link.toPropertyId == toPropertyId;
          return !duplicatesSameDirection;
        })
        .toList(growable: true);

    filteredLinks.add(
      MaterialGraphLink(
        id: _idFactory.next(),
        fromNodeId: fromNodeId,
        fromPropertyId: fromPropertyId,
        toNodeId: toNodeId,
        toPropertyId: toPropertyId,
      ),
    );

    _replaceActiveGraph(activeGraph.copyWith(links: filteredLinks));
    _pendingConnection = null;
    _markDirty(fromNodeId);
    _refreshPreviews();
    notifyListeners();
  }

  void _updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required Object value,
  }) {
    final node = activeGraph.nodes.firstWhere((entry) => entry.id == nodeId);
    final updatedProperties = node.properties
        .map((property) {
          if (property.id != propertyId) {
            return property;
          }

          return property.copyWith(value: value);
        })
        .toList(growable: false);

    _replaceNode(
      node.copyWith(properties: updatedProperties, isDirty: true),
      refreshPreviews: false,
    );
    _markDirty(nodeId);
    _refreshPreviews();
    notifyListeners();
  }

  void _replaceNode(
    GraphNodeInstance updatedNode, {
    required bool refreshPreviews,
  }) {
    _replaceActiveGraph(
      activeGraph.copyWith(
        nodes: activeGraph.nodes
            .map((node) {
              return node.id == updatedNode.id ? updatedNode : node;
            })
            .toList(growable: false),
      ),
    );

    if (refreshPreviews) {
      _refreshPreviews();
    }
  }

  void _replaceActiveGraph(MaterialGraphDocument updatedGraph) {
    final graphs = workspace.graphs
        .map((graph) {
          return graph.id == updatedGraph.id ? updatedGraph : graph;
        })
        .toList(growable: false);
    _workspace = workspace.copyWith(graphs: graphs);
  }

  void _markDirty(String nodeId) {
    final visited = <String>{};
    _markDirtyRecursive(nodeId, visited);
  }

  void _markDirtyRecursive(String nodeId, Set<String> visited) {
    if (!visited.add(nodeId)) {
      return;
    }

    final node = activeGraph.nodes.firstWhereOrNull(
      (entry) => entry.id == nodeId,
    );
    if (node == null) {
      return;
    }

    if (!node.isDirty) {
      _replaceNode(node.copyWith(isDirty: true), refreshPreviews: false);
    }

    for (final link in activeGraph.links.where(
      (entry) => entry.fromNodeId == nodeId,
    )) {
      _markDirtyRecursive(link.toNodeId, visited);
    }
  }

  void _refreshPreviews() {
    _previewRevision += 1;

    final updatedNodes = activeGraph.nodes
        .map((node) {
          final definition = definitionForNode(node);
          _previews[node.id] = _renderer.renderNodePreview(
            definition: definition,
            node: node,
            revision: _previewRevision,
          );
          return node.copyWith(isDirty: false);
        })
        .toList(growable: false);

    _replaceActiveGraph(activeGraph.copyWith(nodes: updatedNodes));
  }
}
