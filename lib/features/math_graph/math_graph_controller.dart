import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_bindings.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'math_graph_catalog.dart';
import 'math_node_definition.dart';
import 'runtime/math_graph_compiler.dart';
import 'runtime/math_graph_ir.dart';

class PendingMathSocketConnection {
  const PendingMathSocketConnection({
    required this.nodeId,
    required this.propertyId,
    required this.direction,
  });

  final String nodeId;
  final String propertyId;
  final GraphSocketDirection direction;
}

class MathGraphController extends ChangeNotifier {
  MathGraphController({
    required IdFactory idFactory,
    required MathGraphCatalog catalog,
    required MathGraphCompiler compiler,
  }) : _idFactory = idFactory,
       _catalog = catalog,
       _compiler = compiler;

  factory MathGraphController.preview() {
    final idFactory = IdFactory();
    final catalog = MathGraphCatalog(idFactory);
    return MathGraphController(
      idFactory: idFactory,
      catalog: catalog,
      compiler: MathGraphCompiler(catalog: catalog),
    );
  }

  final IdFactory _idFactory;
  final MathGraphCatalog _catalog;
  final MathGraphCompiler _compiler;

  GraphDocument? _graph;
  ValueChanged<GraphDocument>? _onGraphChanged;
  String? _selectedNodeId;
  PendingMathSocketConnection? _pendingConnection;
  MathCompileResult? _compileResult;

  bool get hasGraph => _graph != null;

  GraphDocument get graph => _graph!;

  String? get graphId => _graph?.id;

  List<MathNodeDefinition> get nodeDefinitions => _catalog.definitions;

  String? get selectedNodeId => _selectedNodeId;

  PendingMathSocketConnection? get pendingConnection => _pendingConnection;

  MathCompileResult? get compileResult => _compileResult;

  MathCompiledFunction? get compiledFunction =>
      _compileResult?.compiledFunction;

  List<MathCompileDiagnostic> get diagnostics =>
      _compileResult?.diagnostics ?? const <MathCompileDiagnostic>[];

  bool get hasErrors => _compileResult?.hasErrors ?? false;

  GraphNodeDocument? get selectedNode {
    if (_selectedNodeId == null || !hasGraph) {
      return null;
    }
    return graph.nodes.firstWhereOrNull((node) => node.id == _selectedNodeId);
  }

  GraphNodeDocument? nodeById(String nodeId) {
    if (!hasGraph) {
      return null;
    }
    return graph.nodes.firstWhereOrNull((node) => node.id == nodeId);
  }

  List<GraphNodeDocument> get graphInputNodes {
    if (!hasGraph) {
      return const <GraphNodeDocument>[];
    }
    return graph.nodes
        .where((node) => definitionForNode(node).isInputParameter)
        .toList(growable: false);
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
    }
    _recompileGraph(graph);
    notifyListeners();
  }

  void clearGraph() {
    _graph = null;
    _onGraphChanged = null;
    _selectedNodeId = null;
    _pendingConnection = null;
    _compileResult = null;
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
    final matchingNodeCount = hasGraph
        ? graph.nodes.where((node) => node.definitionId == definitionId).length
        : 0;
    addNodeAt(
      definitionId,
      Vector2(760 + (matchingNodeCount * 42), 560 + (matchingNodeCount * 34)),
    );
  }

  void addNodeAt(String definitionId, Vector2 position) {
    if (!hasGraph) {
      return;
    }
    final node = _catalog.instantiateNode(
      definitionId: definitionId,
      position: position,
    );
    _selectedNodeId = node.id;
    _commitGraph(graph.copyWith(nodes: [...graph.nodes, node]));
  }

  void duplicateNode(String nodeId) {
    final source = nodeById(nodeId);
    if (source == null) {
      return;
    }
    final duplicate = GraphNodeDocument(
      id: _idFactory.next(),
      definitionId: source.definitionId,
      name: _nextDuplicateName(source.name),
      position: source.position + Vector2(40, 32),
      properties: source.properties
          .map(
            (property) => GraphNodePropertyData(
              id: _idFactory.next(),
              definitionKey: property.definitionKey,
              value: property.value.deepCopy(),
            ),
          )
          .toList(growable: false),
    );
    _selectedNodeId = duplicate.id;
    _commitGraph(graph.copyWith(nodes: [...graph.nodes, duplicate]));
  }

  void deleteNode(String nodeId) {
    final node = nodeById(nodeId);
    if (node == null) {
      return;
    }
    if (_pendingConnection?.nodeId == nodeId) {
      _pendingConnection = null;
    }
    if (_selectedNodeId == nodeId) {
      _selectedNodeId = null;
    }
    _commitGraph(
      graph.copyWith(
        nodes: graph.nodes
            .where((entry) => entry.id != nodeId)
            .toList(growable: false),
        links: graph.links
            .where(
              (link) => link.fromNodeId != nodeId && link.toNodeId != nodeId,
            )
            .toList(growable: false),
      ),
    );
  }

  void disconnectNode(String nodeId) {
    if (!hasGraph) {
      return;
    }
    final linksToRemove = graph.links
        .where((link) => link.fromNodeId == nodeId || link.toNodeId == nodeId)
        .toList(growable: false);
    if (linksToRemove.isEmpty) {
      return;
    }
    if (_pendingConnection?.nodeId == nodeId) {
      _pendingConnection = null;
    }
    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where(
              (link) => link.fromNodeId != nodeId && link.toNodeId != nodeId,
            )
            .toList(growable: false),
      ),
    );
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
      recompile: false,
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
    final definition = definitionForNode(
      node,
    ).propertyDefinition(property.definitionKey);
    final direction = definition.socketDirection;
    if (direction == null) {
      return;
    }
    if (_pendingConnection == null) {
      if (direction == GraphSocketDirection.output) {
        _pendingConnection = PendingMathSocketConnection(
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
        _pendingConnection = PendingMathSocketConnection(
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
    final link = graph.links.firstWhereOrNull((entry) => entry.id == linkId);
    if (link == null) {
      return;
    }
    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where((entry) => entry.id != linkId)
            .toList(growable: false),
      ),
    );
  }

  void disconnectSocket({required String nodeId, required String propertyId}) {
    if (!hasGraph) {
      return;
    }
    final node = nodeById(nodeId);
    if (node == null || node.propertyById(propertyId) == null) {
      return;
    }
    final linksToRemove = graph.links
        .where(
          (link) =>
              link.fromPropertyId == propertyId ||
              link.toPropertyId == propertyId,
        )
        .toList(growable: false);
    if (linksToRemove.isEmpty) {
      return;
    }
    if (_pendingConnection?.propertyId == propertyId) {
      _pendingConnection = null;
    }
    _commitGraph(
      graph.copyWith(
        links: graph.links
            .where(
              (link) =>
                  link.fromPropertyId != propertyId &&
                  link.toPropertyId != propertyId,
            )
            .toList(growable: false),
      ),
    );
  }

  void updatePropertyValue({
    required String nodeId,
    required String propertyId,
    required GraphValueData value,
  }) {
    final node = graph.nodes.firstWhere((entry) => entry.id == nodeId);
    final updatedProperties = node.properties
        .map(
          (property) => property.id == propertyId
              ? property.copyWith(value: value)
              : property,
        )
        .toList(growable: false);

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

  MathNodeDefinition definitionForNode(GraphNodeDocument node) {
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

  List<MathCompileDiagnostic> diagnosticsForNode(String nodeId) {
    return diagnostics
        .where((diagnostic) => diagnostic.nodeId == nodeId)
        .toList(growable: false);
  }

  MathCompileDiagnostic? firstDiagnosticForNode(String nodeId) {
    return diagnostics.firstWhereOrNull(
      (diagnostic) => diagnostic.nodeId == nodeId,
    );
  }

  bool hasIncomingLink(String propertyId) {
    return hasGraph &&
        graph.links.any((link) => link.toPropertyId == propertyId);
  }

  bool hasOutgoingLink(String propertyId) {
    return hasGraph &&
        graph.links.any((link) => link.fromPropertyId == propertyId);
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
    _commitGraph(graph.copyWith(links: filteredLinks));
  }

  void _commitGraph(GraphDocument updatedGraph, {bool recompile = true}) {
    _graph = updatedGraph;
    if (recompile) {
      _recompileGraph(updatedGraph);
    }
    _onGraphChanged?.call(updatedGraph);
    notifyListeners();
  }

  void _recompileGraph(GraphDocument updatedGraph) {
    _compileResult = _compiler.compile(
      updatedGraph,
      options: MathGraphCompileOptions(functionName: updatedGraph.name),
    );
  }

  String _nextDuplicateName(String baseName) {
    final takenNames = graph.nodes.map((node) => node.name).toSet();
    var index = 1;
    while (true) {
      final suffix = index == 1 ? ' Copy' : ' Copy $index';
      final candidate = '$baseName$suffix';
      if (!takenNames.contains(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }
}
