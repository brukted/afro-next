import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../services/filesystem/app_file_picker.dart';
import '../../services/filesystem/workspace_file_store.dart';
import '../../services/logging/app_logger.dart';
import '../../services/preferences/app_preferences.dart';
import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import '../material_graph/material_output_size.dart';
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
  String? _selectedResourceId;
  String? _openedResourceId;
  String? _currentFilePath;
  bool _initialized = false;
  bool _isDirty = false;

  bool get isInitialized => _initialized;

  bool get isDirty => _isDirty;

  WorkspaceLayoutPreferences get layoutPreferences =>
      _preferences.loadWorkspaceLayout();

  List<String> get recentFiles => _preferences.loadRecentFiles();

  WorkspaceProjectDocument get workspace => _workspace!;

  String? get selectedResourceId => _selectedResourceId;

  String? get openedResourceId => _openedResourceId;

  String? get currentFilePath => _currentFilePath;

  WorkspaceResourceEntry? resourceById(String resourceId) {
    if (_workspace == null) {
      return null;
    }

    return workspace.resources.firstWhereOrNull(
      (entry) => entry.id == resourceId,
    );
  }

  WorkspaceResourceEntry? get selectedResource {
    if (_workspace == null || _selectedResourceId == null) {
      return null;
    }

    return workspace.resources.firstWhereOrNull(
      (entry) => entry.id == _selectedResourceId,
    );
  }

  WorkspaceResourceEntry? get openedResource {
    if (_workspace == null || _openedResourceId == null) {
      return null;
    }

    return workspace.resources.firstWhereOrNull(
      (entry) => entry.id == _openedResourceId,
    );
  }

  MaterialGraphResourceDocument? get openedMaterialGraphDocument {
    final resource = openedResource;
    if (resource == null ||
        resource.kind != WorkspaceResourceKind.materialGraph) {
      return null;
    }

    return workspace.materialGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  MathGraphResourceDocument? get openedMathGraphDocument {
    final resource = openedResource;
    if (resource == null || resource.kind != WorkspaceResourceKind.mathGraph) {
      return null;
    }

    return workspace.mathGraphs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  ImageResourceDocument? get openedImageDocument {
    final resource = openedResource;
    if (resource == null || resource.kind != WorkspaceResourceKind.image) {
      return null;
    }

    return workspace.images.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  SvgResourceDocument? get openedSvgDocument {
    final resource = openedResource;
    if (resource == null || resource.kind != WorkspaceResourceKind.svg) {
      return null;
    }

    return workspace.svgs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  ImageResourceDocument? imageDocumentByResourceId(String resourceId) {
    final resource = resourceById(resourceId);
    if (resource == null || resource.kind != WorkspaceResourceKind.image) {
      return null;
    }
    return workspace.images.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  SvgResourceDocument? svgDocumentByResourceId(String resourceId) {
    final resource = resourceById(resourceId);
    if (resource == null || resource.kind != WorkspaceResourceKind.svg) {
      return null;
    }
    return workspace.svgs.firstWhereOrNull(
      (entry) => entry.id == resource.documentId,
    );
  }

  List<WorkspaceResourceEntry> resourcesForKinds(
    Set<WorkspaceResourceKind> kinds,
  ) {
    return workspace.resources
        .where((entry) => kinds.contains(entry.kind))
        .toList(growable: false)
      ..sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _workspace = _createInitialWorkspace();
    _selectedResourceId = workspace.resources
        .firstWhere(
          (entry) => entry.kind == WorkspaceResourceKind.materialGraph,
        )
        .id;
    _openedResourceId = _selectedResourceId;
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
    _selectedResourceId = workspace.resources
        .firstWhere(
          (entry) => entry.kind == WorkspaceResourceKind.materialGraph,
        )
        .id;
    _openedResourceId = _selectedResourceId;
    _initialized = true;
  }

  Future<void> openWorkspaceFile() async {
    final path = await _filePicker.openWorkspaceFile();
    if (path == null) {
      return;
    }

    await openWorkspaceFromPath(path);
  }

  Future<void> openWorkspaceFromPath(String path) async {
    final loadedWorkspace = await _fileStore.load(path);
    _workspace = loadedWorkspace;
    _currentFilePath = path;
    _selectedResourceId = _pickInitialResource(loadedWorkspace);
    _openedResourceId = _selectedResourceId;
    _isDirty = false;
    await _preferences.rememberRecentFile(path);
    _logger.info('Opened workspace file: $path');
    notifyListeners();
  }

  void newUntitledWorkspace() {
    _workspace = _createInitialWorkspace();
    _currentFilePath = null;
    _selectedResourceId = _pickInitialResource(workspace);
    _openedResourceId = _selectedResourceId;
    _isDirty = false;
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
    if (_selectedResourceId == resourceId) {
      return;
    }

    _selectedResourceId = resourceId;
    notifyListeners();
  }

  void openResource(String resourceId) {
    final resource = resourceById(resourceId);
    if (resource == null) {
      return;
    }

    if (_selectedResourceId == resource.id &&
        _openedResourceId == resource.id) {
      return;
    }

    _selectedResourceId = resource.id;
    _openedResourceId = resource.id;
    notifyListeners();
  }

  List<String> ancestorIdsOf(String resourceId) {
    final ancestors = <String>[];
    var current = resourceById(resourceId);
    while (current?.parentId != null) {
      final parentId = current!.parentId!;
      ancestors.add(parentId);
      current = resourceById(parentId);
    }

    return ancestors;
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
    createFolderAt(_creationParentId());
  }

  void createMaterialGraph() {
    createMaterialGraphAt(_creationParentId());
  }

  void createMathGraph() {
    createMathGraphAt(_creationParentId());
  }

  Future<void> importImage() => importImageAt(_creationParentId());

  Future<void> importSvg() => importSvgAt(_creationParentId());

  void createFolderAt(String? parentId) {
    final folder = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: _nextName('Folder', WorkspaceResourceKind.folder),
      kind: WorkspaceResourceKind.folder,
      parentId: _normalizeParentId(parentId),
    );

    _selectedResourceId = folder.id;
    _replaceWorkspace(
      workspace.copyWith(resources: [...workspace.resources, folder]),
    );
  }

  void createMaterialGraphAt(String? parentId) {
    final graphName = _nextName(
      'Material Graph',
      WorkspaceResourceKind.materialGraph,
    );
    final document = MaterialGraphResourceDocument(
      id: _idFactory.next(),
      graph: GraphDocument.empty(id: _idFactory.next(), name: graphName),
      outputSizeSettings: const MaterialOutputSizeSettings(),
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: graphName,
      kind: WorkspaceResourceKind.materialGraph,
      parentId: _normalizeParentId(parentId),
      documentId: document.id,
    );

    _selectedResourceId = resource.id;
    _openedResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        materialGraphs: [...workspace.materialGraphs, document],
      ),
    );
  }

  void createMathGraphAt(String? parentId) {
    final graphName = _nextName('Math Graph', WorkspaceResourceKind.mathGraph);
    final document = MathGraphResourceDocument(
      id: _idFactory.next(),
      graph: GraphDocument.empty(id: _idFactory.next(), name: graphName),
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: graphName,
      kind: WorkspaceResourceKind.mathGraph,
      parentId: _normalizeParentId(parentId),
      documentId: document.id,
    );

    _selectedResourceId = resource.id;
    _openedResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        mathGraphs: [...workspace.mathGraphs, document],
      ),
    );
  }

  Future<void> importImageAt(String? parentId) async {
    final pickedPath = await _filePicker.openImageResourceFile();
    if (pickedPath == null) {
      return;
    }
    await importImageFileAt(pickedPath, parentId);
  }

  Future<void> importSvgAt(String? parentId) async {
    final pickedPath = await _filePicker.openSvgResourceFile();
    if (pickedPath == null) {
      return;
    }
    await importSvgFileAt(pickedPath, parentId);
  }

  Future<void> importImageFileAt(String filePath, String? parentId) async {
    final bytes = await File(filePath).readAsBytes();
    final sourceName = path.basename(filePath);
    final document = ImageResourceDocument(
      id: _idFactory.next(),
      sourceName: sourceName,
      encodedBytesBase64: base64Encode(bytes),
      mimeType: _mimeTypeForPath(filePath),
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: _uniqueResourceName(sourceName, WorkspaceResourceKind.image),
      kind: WorkspaceResourceKind.image,
      parentId: _normalizeParentId(parentId),
      documentId: document.id,
    );

    _selectedResourceId = resource.id;
    _openedResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        images: [...workspace.images, document],
      ),
    );
  }

  Future<void> importSvgFileAt(String filePath, String? parentId) async {
    final svgText = await File(filePath).readAsString();
    final sourceName = path.basename(filePath);
    final document = SvgResourceDocument(
      id: _idFactory.next(),
      sourceName: sourceName,
      svgText: svgText,
    );
    final resource = WorkspaceResourceEntry(
      id: _idFactory.next(),
      name: _uniqueResourceName(sourceName, WorkspaceResourceKind.svg),
      kind: WorkspaceResourceKind.svg,
      parentId: _normalizeParentId(parentId),
      documentId: document.id,
    );

    _selectedResourceId = resource.id;
    _openedResourceId = resource.id;
    _replaceWorkspace(
      workspace.copyWith(
        resources: [...workspace.resources, resource],
        svgs: [...workspace.svgs, document],
      ),
    );
  }

  bool canRenameResource(String resourceId) =>
      resourceId != workspace.rootFolderId;

  bool canDeleteResource(String resourceId) =>
      resourceId != workspace.rootFolderId;

  void renameResource({required String resourceId, required String nextName}) {
    final normalizedName = nextName.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final resource = resourceById(resourceId);
    if (resource == null || !canRenameResource(resourceId)) {
      return;
    }

    final resources = workspace.resources
        .map(
          (entry) => entry.id == resourceId
              ? entry.copyWith(name: normalizedName)
              : entry,
        )
        .toList(growable: false);

    var materialGraphs = workspace.materialGraphs;
    var mathGraphs = workspace.mathGraphs;
    if (resource.kind == WorkspaceResourceKind.materialGraph &&
        resource.documentId != null) {
      materialGraphs = workspace.materialGraphs
          .map(
            (entry) => entry.id == resource.documentId
                ? entry.copyWith(
                    graph: entry.graph.copyWith(name: normalizedName),
                  )
                : entry,
          )
          .toList(growable: false);
    }
    if (resource.kind == WorkspaceResourceKind.mathGraph &&
        resource.documentId != null) {
      mathGraphs = workspace.mathGraphs
          .map(
            (entry) => entry.id == resource.documentId
                ? entry.copyWith(
                    graph: entry.graph.copyWith(name: normalizedName),
                  )
                : entry,
          )
          .toList(growable: false);
    }

    _replaceWorkspace(
      workspace.copyWith(
        resources: resources,
        materialGraphs: materialGraphs,
        mathGraphs: mathGraphs,
      ),
    );
  }

  void deleteResource(String resourceId) {
    if (!canDeleteResource(resourceId)) {
      return;
    }

    final resource = resourceById(resourceId);
    if (resource == null) {
      return;
    }

    final removedIds = _collectResourceIds(resourceId);
    final removedResources = workspace.resources
        .where((entry) => removedIds.contains(entry.id))
        .toList(growable: false);
    final removedMaterialDocumentIds = removedResources
        .where((entry) => entry.kind == WorkspaceResourceKind.materialGraph)
        .map((entry) => entry.documentId)
        .nonNulls
        .toSet();
    final removedMathDocumentIds = removedResources
        .where((entry) => entry.kind == WorkspaceResourceKind.mathGraph)
        .map((entry) => entry.documentId)
        .nonNulls
        .toSet();
    final removedImageDocumentIds = removedResources
        .where((entry) => entry.kind == WorkspaceResourceKind.image)
        .map((entry) => entry.documentId)
        .nonNulls
        .toSet();
    final removedSvgDocumentIds = removedResources
        .where((entry) => entry.kind == WorkspaceResourceKind.svg)
        .map((entry) => entry.documentId)
        .nonNulls
        .toSet();

    final updatedWorkspace = workspace.copyWith(
      resources: workspace.resources
          .where((entry) => !removedIds.contains(entry.id))
          .toList(growable: false),
      materialGraphs: workspace.materialGraphs
          .where((entry) => !removedMaterialDocumentIds.contains(entry.id))
          .toList(growable: false),
      mathGraphs: workspace.mathGraphs
          .where((entry) => !removedMathDocumentIds.contains(entry.id))
          .toList(growable: false),
      images: workspace.images
          .where((entry) => !removedImageDocumentIds.contains(entry.id))
          .toList(growable: false),
      svgs: workspace.svgs
          .where((entry) => !removedSvgDocumentIds.contains(entry.id))
          .toList(growable: false),
    );

    _workspace = updatedWorkspace;
    if (_selectedResourceId != null &&
        removedIds.contains(_selectedResourceId)) {
      _selectedResourceId = _pickFallbackResource(
        updatedWorkspace,
        preferredParentId: resource.parentId,
      );
    }
    if (_openedResourceId != null && removedIds.contains(_openedResourceId)) {
      _openedResourceId = _pickFallbackResource(
        updatedWorkspace,
        preferredParentId: resource.parentId,
      );
    }
    _isDirty = true;
    notifyListeners();
  }

  void updateActiveMaterialGraph(GraphDocument graph) {
    final resource = openedResource;
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

  void updateActiveMaterialGraphOutputSizeSettings(
    MaterialOutputSizeSettings outputSizeSettings,
  ) {
    final resource = openedResource;
    if (resource == null || resource.documentId == null) {
      return;
    }

    final materialGraphs = workspace.materialGraphs
        .map(
          (entry) => entry.id == resource.documentId
              ? entry.copyWith(outputSizeSettings: outputSizeSettings)
              : entry,
        )
        .toList(growable: false);

    _replaceWorkspace(workspace.copyWith(materialGraphs: materialGraphs));
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
    final resource = selectedResource;
    if (resource == null) {
      return workspace.rootFolderId;
    }

    if (resource.kind == WorkspaceResourceKind.folder) {
      return resource.id;
    }

    return resource.parentId ?? workspace.rootFolderId;
  }

  String _normalizeParentId(String? parentId) {
    if (parentId == null) {
      return workspace.rootFolderId;
    }

    final parent = resourceById(parentId);
    if (parent == null) {
      return workspace.rootFolderId;
    }

    if (parent.kind == WorkspaceResourceKind.folder) {
      return parent.id;
    }

    return parent.parentId ?? workspace.rootFolderId;
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

  String _uniqueResourceName(String preferredName, WorkspaceResourceKind kind) {
    final normalized = preferredName.trim();
    if (normalized.isEmpty) {
      return _nextName(kind.name, kind);
    }
    final existingNames = workspace.resources
        .where((entry) => entry.kind == kind)
        .map((entry) => entry.name)
        .toSet();
    if (!existingNames.contains(normalized)) {
      return normalized;
    }
    final extension = path.extension(normalized);
    final baseName = extension.isEmpty
        ? normalized
        : normalized.substring(0, normalized.length - extension.length);
    var index = 2;
    while (true) {
      final candidate = '$baseName $index$extension';
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

  Set<String> _collectResourceIds(String resourceId) {
    final ids = <String>{resourceId};
    final pending = <String>[resourceId];

    while (pending.isNotEmpty) {
      final currentId = pending.removeLast();
      final childIds = workspace.resources
          .where((entry) => entry.parentId == currentId)
          .map((entry) => entry.id)
          .where(ids.add)
          .toList(growable: false);
      pending.addAll(childIds);
    }

    return ids;
  }

  String? _pickFallbackResource(
    WorkspaceProjectDocument workspace, {
    String? preferredParentId,
  }) {
    if (preferredParentId != null &&
        workspace.resources.any((entry) => entry.id == preferredParentId)) {
      return preferredParentId;
    }

    return workspace.resources
            .firstWhereOrNull(
              (entry) => entry.kind == WorkspaceResourceKind.materialGraph,
            )
            ?.id ??
        workspace.resources
            .firstWhereOrNull((entry) => entry.id != workspace.rootFolderId)
            ?.id;
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
          graph: GraphDocument.empty(
            id: _idFactory.next(),
            name: 'Math Graph 1',
          ),
        ),
      ],
      images: const <ImageResourceDocument>[],
      svgs: const <SvgResourceDocument>[],
    );
  }

  String? _mimeTypeForPath(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.bmp' => 'image/bmp',
      '.webp' => 'image/webp',
      _ => null,
    };
  }
}
