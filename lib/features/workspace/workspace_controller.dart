import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../services/filesystem/app_file_picker.dart';
import '../../services/filesystem/workspace_file_store.dart';
import '../../services/logging/app_logger.dart';
import '../../services/preferences/app_preferences.dart';
import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import 'models/workspace_models.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required IdFactory idFactory,
    required AppPreferences preferences,
    required AppFilePicker filePicker,
    required AppLogger logger,
    required WorkspaceFileStore fileStore,
  }) : _idFactory = idFactory,
       _preferences = preferences,
       _filePicker = filePicker,
       _logger = logger,
       _fileStore = fileStore;

  factory WorkspaceController.preview() {
    return WorkspaceController(
      idFactory: IdFactory(),
      preferences: AppPreferences.memory(),
      filePicker: const AppFilePicker.noop(),
      logger: AppLogger.memory(),
      fileStore: const WorkspaceFileStore(),
    );
  }

  final IdFactory _idFactory;
  final AppPreferences _preferences;
  final AppFilePicker _filePicker;
  final AppLogger _logger;
  final WorkspaceFileStore _fileStore;

  WorkspaceProjectDocument? _workspace;
  String? _activeResourceId;
  String? _currentFilePath;
  bool _initialized = false;
  bool _isDirty = false;

  bool get isInitialized => _initialized;

  bool get isDirty => _isDirty;

  WorkspaceLayoutPreferences get layoutPreferences =>
      _preferences.loadWorkspaceLayout();

  List<String> get recentFiles => _preferences.loadRecentFiles();

  WorkspaceProjectDocument get workspace => _workspace!;

  String? get activeResourceId => _activeResourceId;

  String? get currentFilePath => _currentFilePath;

  WorkspaceResourceEntry? get activeResource {
    if (_workspace == null || _activeResourceId == null) {
      return null;
    }

    return workspace.resources.firstWhereOrNull(
      (entry) => entry.id == _activeResourceId,
    );
  }

  MaterialGraphResourceDocument? get activeMaterialGraphDocument {
    final resource = activeResource;
    if (resource == null || resource.kind != WorkspaceResourceKind.materialGraph) {
      return null;
    }

    return workspace.materialGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  MathGraphResourceDocument? get activeMathGraphDocument {
    final resource = activeResource;
    if (resource == null || resource.kind != WorkspaceResourceKind.mathGraph) {
      return null;
    }

    return workspace.mathGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _workspace = _createInitialWorkspace();
    _activeResourceId = workspace.resources
        .firstWhere((entry) => entry.kind == WorkspaceResourceKind.materialGraph)
        .id;
    _initialized = true;
    _logger.info(
      'Workspace initialized with ${workspace.resources.length} resources.',
    );
    notifyListeners();
  }

  void initializeForPreview() {
    if (_initialized) {
      return;
    }

    _workspace = _createInitialWorkspace();
    _activeResourceId = workspace.resources
        .firstWhere((entry) => entry.kind == WorkspaceResourceKind.materialGraph)
        .id;
    _initialized = true;
  }

  Future<void> openWorkspaceFile() async {
    final path = await _filePicker.openWorkspaceFile();
    if (path == null) {
      return;
    }

    final loadedWorkspace = await _fileStore.load(path);
    _workspace = loadedWorkspace;
    _currentFilePath = path;
    _activeResourceId = _pickInitialResource(loadedWorkspace);
    _isDirty = false;
    await _preferences.rememberRecentFile(path);
    _logger.info('Opened workspace file: $path');
    notifyListeners();
  }

  Future<void> saveWorkspaceFile() async {
    if (_currentFilePath == null) {
      await saveWorkspaceAs();
      return;
    }

    await _persistWorkspace(_currentFilePath!);
  }

  Future<void> saveWorkspaceAs() async {
    final path = await _filePicker.saveWorkspaceFile();
    if (path == null) {
      return;
    }

    _currentFilePath = path;
    await _persistWorkspace(path);
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

  void selectResource(String resourceId) {
    if (_activeResourceId == resourceId) {
      return;
    }

    _activeResourceId = resourceId;
    notifyListeners();
  }

  List<WorkspaceResourceEntry> childrenOf(String? parentId) {
    return workspace.resources
        .where((entry) => entry.parentId == parentId)
        .toList(growable: false)
      ..sort((left, right) {
        if (left.kind == WorkspaceResourceKind.folder &&
            right.kind != WorkspaceResourceKind.folder) {
          return -1;
        }
        if (left.kind != WorkspaceResourceKind.folder &&
            right.kind == WorkspaceResourceKind.folder) {
          return 1;
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
  }

  void createFolder() {
    final folder = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: _nextName('Folder', WorkspaceResourceKind.folder),
      kind: WorkspaceResourceKind.folder,
      parentId: _creationParentId(),
    );

    _activeResourceId = folder.id;
    _replaceWorkspace(
      workspace.copyWith(resources: [...workspace.resources, folder]),
    );
  }

  void createMaterialGraph() {
    final graphName = _nextName(
      'Material Graph',
      WorkspaceResourceKind.materialGraph,
    );
    final document = MaterialGraphResourceDocument(
      id: _idFactory.next(),
      graph: GraphDocument.empty(id: _idFactory.next(), name: graphName),
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: graphName,
      kind: WorkspaceResourceKind.materialGraph,
      parentId: _creationParentId(),
      documentId: document.id,
    );

    _activeResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        materialGraphs: [...workspace.materialGraphs, document],
      ),
    );
  }

  void createMathGraph() {
    final graphName = _nextName('Math Graph', WorkspaceResourceKind.mathGraph);
    final document = MathGraphResourceDocument(
      id: _idFactory.next(),
      graph: GraphDocument.empty(id: _idFactory.next(), name: graphName),
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: graphName,
      kind: WorkspaceResourceKind.mathGraph,
      parentId: _creationParentId(),
      documentId: document.id,
    );

    _activeResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        mathGraphs: [...workspace.mathGraphs, document],
      ),
    );
  }

  void updateActiveMaterialGraph(GraphDocument graph) {
    final resource = activeResource;
    if (resource == null || resource.documentId == null) {
      return;
    }

    final materialGraphs = workspace.materialGraphs
        .map(
          (entry) => entry.id == resource.documentId
              ? entry.copyWith(graph: graph)
              : entry,
        )
        .toList(growable: false);

    final resources = workspace.resources
        .map(
          (entry) => entry.id == resource.id
              ? entry.copyWith(name: graph.name)
              : entry,
        )
        .toList(growable: false);

    _replaceWorkspace(
      workspace.copyWith(resources: resources, materialGraphs: materialGraphs),
    );
  }

  void _replaceWorkspace(WorkspaceProjectDocument updatedWorkspace) {
    _workspace = updatedWorkspace;
    _isDirty = true;
    notifyListeners();
  }

  Future<void> _persistWorkspace(String path) async {
    await _fileStore.save(path: path, workspace: workspace);
    await _preferences.rememberRecentFile(path);
    _isDirty = false;
    _logger.info('Saved workspace file: $path');
    notifyListeners();
  }

  String _creationParentId() {
    final resource = activeResource;
    if (resource == null) {
      return workspace.rootFolderId;
    }

    if (resource.kind == WorkspaceResourceKind.folder) {
      return resource.id;
    }

    return resource.parentId ?? workspace.rootFolderId;
  }

  String _nextName(String base, WorkspaceResourceKind kind) {
    final existingNames = workspace.resources
        .where((entry) => entry.kind == kind && entry.name.startsWith(base))
        .map((entry) => entry.name)
        .toSet();

    var index = 1;
    while (true) {
      final candidate = '$base $index';
      if (!existingNames.contains(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  String _pickInitialResource(WorkspaceProjectDocument workspace) {
    return workspace.resources
            .firstWhereOrNull(
              (entry) => entry.kind == WorkspaceResourceKind.materialGraph,
            )
            ?.id ??
        workspace.resources
            .firstWhere((entry) => entry.id != workspace.rootFolderId)
            .id;
  }

  WorkspaceProjectDocument _createInitialWorkspace() {
    final rootFolderId = _idFactory.next();
    final materialsFolderId = _idFactory.next();
    final mathFolderId = _idFactory.next();
    final materialDocumentId = _idFactory.next();
    final mathDocumentId = _idFactory.next();

    return WorkspaceProjectDocument(
      id: _idFactory.next(),
      name: 'Eyecandy Workspace',
      rootFolderId: rootFolderId,
      resources: [
        WorkspaceResourceEntry(
          id: rootFolderId,
          name: 'Root',
          kind: WorkspaceResourceKind.folder,
        ),
        WorkspaceResourceEntry(
          id: materialsFolderId,
          name: 'Materials',
          kind: WorkspaceResourceKind.folder,
          parentId: rootFolderId,
        ),
        WorkspaceResourceEntry(
          id: mathFolderId,
          name: 'Math',
          kind: WorkspaceResourceKind.folder,
          parentId: rootFolderId,
        ),
        WorkspaceResourceEntry(
          id: _idFactory.next(),
          name: 'Material Graph 1',
          kind: WorkspaceResourceKind.materialGraph,
          parentId: materialsFolderId,
          documentId: materialDocumentId,
        ),
        WorkspaceResourceEntry(
          id: _idFactory.next(),
          name: 'Math Graph 1',
          kind: WorkspaceResourceKind.mathGraph,
          parentId: mathFolderId,
          documentId: mathDocumentId,
        ),
      ],
      materialGraphs: [
        MaterialGraphResourceDocument(
          id: materialDocumentId,
          graph: GraphDocument.empty(
            id: _idFactory.next(),
            name: 'Material Graph 1',
          ),
        ),
      ],
      mathGraphs: [
        MathGraphResourceDocument(
          id: mathDocumentId,
          graph: GraphDocument.empty(id: _idFactory.next(), name: 'Math Graph 1'),
        ),
      ],
    );
  }
}
