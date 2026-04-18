import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

import '../../shared/colors/vector4_color_adapter.dart';
import '../../shared/ids/id_factory.dart';
import '../../vulkan/bootstrap/vulkan_bootstrap.dart';
import '../../vulkan/renderer/placeholder_renderer.dart';
import '../../vulkan/renderer/renderer_facade.dart';
import '../../vulkan/resources/preview_render_target.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'material_graph_catalog.dart';
import 'material_node_definition.dart';

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

class MaterialGraphController extends ChangeNotifier {
  MaterialGraphController({
    required IdFactory idFactory,
    required RendererFacade renderer,
  }) : _idFactory = idFactory,
       _renderer = renderer,
       _catalog = MaterialGraphCatalog(idFactory);

  factory MaterialGraphController.preview() {
    final idFactory = IdFactory();
    return MaterialGraphController(
      idFactory: idFactory,
      renderer: const PreviewOnlyRendererFacade(),
    );
  }

  final IdFactory _idFactory;
  final RendererFacade _renderer;
  final MaterialGraphCatalog _catalog;

  GraphDocument? _graph;
  ValueChanged<GraphDocument>? _onGraphChanged;
  String? _selectedNodeId;
  PendingSocketConnection? _pendingConnection;
  RendererBootstrapState _rendererState =
      const RendererBootstrapState.preview();
  final Map<String, PreviewRenderTarget> _previews =
      <String, PreviewRenderTarget>{};
  final Set<String> _dirtyNodes = <String>{};
  bool _initialized = false;
  int _previewRevision = 0;

  bool get isInitialized => _initialized;

  bool get hasGraph => _graph != null;

  String? get graphId => _graph?.id;

  RendererBootstrapState get rendererState => _rendererState;

  List<MaterialNodeDefinition> get nodeDefinitions => _catalog.definitions;

  GraphDocument get graph => _graph!;

  String? get selectedNodeId => _selectedNodeId;

  PendingSocketConnection? get pendingConnection => _pendingConnection;

  GraphNodeDocument? get selectedNode {
    if (_selectedNodeId == null || _graph == null) {
      return null;
    }

    return graph.nodes.firstWhereOrNull((node) => node.id == _selectedNodeId);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _rendererState = await _renderer.bootstrap();
    _initialized = true;
    notifyListeners();
  }

  void bindGraph({
    required GraphDocument graph,
    required ValueChanged<GraphDocument> onChanged,
  }) {
    final graphChanged = _graph?.id != graph.id;
    _graph = graph;
    _onGraphChanged = onChanged;
    if (graphChanged) {
      _selectedNodeId = null;
      _pendingConnection = null;
      _previews.clear();
      _dirtyNodes
        ..clear()
        ..addAll(graph.nodes.map((node) => node.id));
    }
    _refreshPreviews();
    notifyListeners();
  }

  void clearGraph() {
    _graph = null;
    _onGraphChanged = null;
    _selectedNodeId = null;
    _pendingConnection = null;
    _previews.clear();
    _dirtyNodes.clear();
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
    if (!hasGraph) {
      return;
    }

    final matchingNodeCount = graph.nodes
        .where((node) => node.definitionId == definitionId)
        .length;

    final node = _catalog.instantiateNode(
      definitionId: definitionId,
      position: Vector2(
        760 + (matchingNodeCount * 42),
        560 + (matchingNodeCount * 34),
      ),
      sequence: matchingNodeCount + 1,
    );

    _selectedNodeId = node.id;
    _dirtyNodes.add(node.id);
    _commitGraph(graph.copyWith(nodes: [...graph.nodes, node]));
  }

  void setNodePosition(String nodeId, Vector2 position) {
    if (!hasGraph) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(position: position)
                  : entry,
            )
            .toList(growable: false),
      ),
      refreshPreviews: false,
    );
  }

  void handleSocketTap({required String nodeId, required String propertyId}) {
    if (!hasGraph) {
      return;
    }

    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final property = node.propertyById(propertyId);
    if (property == null) {
      return;
    }

    final definition = definitionForNode(node).propertyDefinition(
      property.definitionKey,
    );
    final direction = definition.socketDirection;
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
    if (!hasGraph) {
      return;
    }

    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where((link) => link.id != linkId)
            .toList(growable: false),
      ),
    );
  }

  void updateScalarProperty({
    required String nodeId,
    required String propertyId,
    required double value,
  }) {
    _updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.scalar(value),
    );
  }

  void updateEnumProperty({
    required String nodeId,
    required String propertyId,
    required int value,
  }) {
    _updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.enumChoice(value),
    );
  }

  void updateColorProperty({
    required String nodeId,
    required String propertyId,
    double? red,
    double? green,
    double? blue,
    double? alpha,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final current = node.propertyById(propertyId)?.value.colorValue ?? Vector4.zero();
    _updatePropertyValue(
      nodeId: nodeId,
      propertyId: propertyId,
      value: GraphValueData.color(
        Vector4ColorAdapter.withChannel(
          current,
          red: red,
          green: green,
          blue: blue,
          alpha: alpha,
        ),
      ),
    );
  }

  MaterialNodeDefinition definitionForNode(GraphNodeDocument node) {
    return _catalog.definitionById(node.definitionId);
  }

  List<GraphPropertyBinding> boundPropertiesForNode(GraphNodeDocument node) {
    final definition = definitionForNode(node);
    return definition.properties
        .map((propertyDefinition) {
          final property = node.properties.firstWhere(
            (entry) => entry.definitionKey == propertyDefinition.key,
          );
          return GraphPropertyBinding(
            property: property,
            definition: propertyDefinition,
          );
        })
        .toList(growable: false);
  }

  PreviewRenderTarget? previewForNode(String nodeId) => _previews[nodeId];

  bool hasIncomingLink(String propertyId) {
    return graph.links.any((link) => link.toPropertyId == propertyId);
  }

  bool hasOutgoingLink(String propertyId) {
    return graph.links.any((link) => link.fromPropertyId == propertyId);
  }

  void _connectProperties({
    required String fromNodeId,
    required String fromPropertyId,
    required String toNodeId,
    required String toPropertyId,
  }) {
    final filteredLinks = graph.links
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
      GraphLinkDocument(
        id: _idFactory.next(),
        fromNodeId: fromNodeId,
        fromPropertyId: fromPropertyId,
        toNodeId: toNodeId,
        toPropertyId: toPropertyId,
      ),
    );

    _pendingConnection = null;
    _markDirty(fromNodeId);
    _commitGraph(graph.copyWith(links: filteredLinks));
  }

  void _updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required GraphValueData value,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final updatedProperties = node.properties
        .map(
          (property) =>
              property.id == propertyId ? property.copyWith(value: value) : property,
        )
        .toList(growable: false);

    _markDirty(nodeId);
    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .map(
              (entry) => entry.id == nodeId
                  ? entry.copyWith(properties: updatedProperties)
                  : entry,
            )
            .toList(growable: false),
      ),
    );
  }

  void _markDirty(String nodeId) {
    final visited = <String>{};
    _markDirtyRecursive(nodeId, visited);
  }

  void _markDirtyRecursive(String nodeId, Set<String> visited) {
    if (!visited.add(nodeId)) {
      return;
    }

    _dirtyNodes.add(nodeId);
    for (final link in graph.links.where((entry) => entry.fromNodeId == nodeId)) {
      _markDirtyRecursive(link.toNodeId, visited);
    }
  }

  void _commitGraph(GraphDocument updatedGraph, {bool refreshPreviews = true}) {
    _graph = updatedGraph;
    _onGraphChanged?.call(updatedGraph);
    if (refreshPreviews) {
      _refreshPreviews();
    }
    notifyListeners();
  }

  void _refreshPreviews() {
    if (!hasGraph) {
      return;
    }

    _previewRevision += 1;
    for (final node in graph.nodes) {
      final definition = definitionForNode(node);
      final bindings = boundPropertiesForNode(node);
      _previews[node.id] = _renderer.renderNodePreview(
        definition: definition,
        node: node,
        bindings: bindings,
        revision: _previewRevision,
        isDirty: _dirtyNodes.contains(node.id),
      );
    }
    _dirtyNodes.clear();
  }
}
