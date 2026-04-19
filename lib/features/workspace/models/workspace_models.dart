import 'package:json_annotation/json_annotation.dart';

import '../../graph/models/graph_models.dart';
import '../../material_graph/material_output_size.dart';

part 'workspace_models.g.dart';

enum WorkspaceResourceKind { folder, materialGraph, mathGraph, image, svg }

@JsonSerializable()
class WorkspaceResourceEntry {
  const WorkspaceResourceEntry({
    required this.id,
    required this.name,
    required this.kind,
    this.parentId,
    this.documentId,
  });

  final String id;
  final String name;
  final WorkspaceResourceKind kind;
  final String? parentId;
  final String? documentId;

  WorkspaceResourceEntry copyWith({
    String? id,
    String? name,
    WorkspaceResourceKind? kind,
    Object? parentId = _sentinel,
    Object? documentId = _sentinel,
  }) {
    return WorkspaceResourceEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      parentId: identical(parentId, _sentinel)
          ? this.parentId
          : parentId as String?,
      documentId: identical(documentId, _sentinel)
          ? this.documentId
          : documentId as String?,
    );
  }

  factory WorkspaceResourceEntry.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceResourceEntryFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceResourceEntryToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MaterialGraphResourceDocument {
  const MaterialGraphResourceDocument({
    required this.id,
    required this.graph,
    this.outputSizeSettings = const MaterialOutputSizeSettings(),
  });

  final String id;
  final GraphDocument graph;
  final MaterialOutputSizeSettings outputSizeSettings;

  MaterialGraphResourceDocument copyWith({
    String? id,
    GraphDocument? graph,
    MaterialOutputSizeSettings? outputSizeSettings,
  }) {
    return MaterialGraphResourceDocument(
      id: id ?? this.id,
      graph: graph ?? this.graph,
      outputSizeSettings: outputSizeSettings ?? this.outputSizeSettings,
    );
  }

  factory MaterialGraphResourceDocument.fromJson(Map<String, dynamic> json) =>
      _$MaterialGraphResourceDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$MaterialGraphResourceDocumentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MathGraphResourceDocument {
  const MathGraphResourceDocument({required this.id, required this.graph});

  final String id;
  final GraphDocument graph;

  MathGraphResourceDocument copyWith({String? id, GraphDocument? graph}) {
    return MathGraphResourceDocument(
      id: id ?? this.id,
      graph: graph ?? this.graph,
    );
  }

  factory MathGraphResourceDocument.fromJson(Map<String, dynamic> json) =>
      _$MathGraphResourceDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$MathGraphResourceDocumentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ImageResourceDocument {
  const ImageResourceDocument({
    required this.id,
    required this.sourceName,
    required this.encodedBytesBase64,
    this.mimeType,
  });

  final String id;
  final String sourceName;
  final String encodedBytesBase64;
  final String? mimeType;

  ImageResourceDocument copyWith({
    String? id,
    String? sourceName,
    String? encodedBytesBase64,
    Object? mimeType = _sentinel,
  }) {
    return ImageResourceDocument(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      encodedBytesBase64: encodedBytesBase64 ?? this.encodedBytesBase64,
      mimeType: identical(mimeType, _sentinel)
          ? this.mimeType
          : mimeType as String?,
    );
  }

  factory ImageResourceDocument.fromJson(Map<String, dynamic> json) =>
      _$ImageResourceDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$ImageResourceDocumentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class SvgResourceDocument {
  const SvgResourceDocument({
    required this.id,
    required this.sourceName,
    required this.svgText,
  });

  final String id;
  final String sourceName;
  final String svgText;

  SvgResourceDocument copyWith({
    String? id,
    String? sourceName,
    String? svgText,
  }) {
    return SvgResourceDocument(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      svgText: svgText ?? this.svgText,
    );
  }

  factory SvgResourceDocument.fromJson(Map<String, dynamic> json) =>
      _$SvgResourceDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$SvgResourceDocumentToJson(this);
}

@JsonSerializable(explicitToJson: true)
class WorkspaceProjectDocument {
  const WorkspaceProjectDocument({
    required this.id,
    required this.name,
    required this.rootFolderId,
    required this.resources,
    required this.materialGraphs,
    required this.mathGraphs,
    this.images = const <ImageResourceDocument>[],
    this.svgs = const <SvgResourceDocument>[],
  });

  final String id;
  final String name;
  final String rootFolderId;
  final List<WorkspaceResourceEntry> resources;
  final List<MaterialGraphResourceDocument> materialGraphs;
  final List<MathGraphResourceDocument> mathGraphs;
  final List<ImageResourceDocument> images;
  final List<SvgResourceDocument> svgs;

  WorkspaceProjectDocument copyWith({
    String? id,
    String? name,
    String? rootFolderId,
    List<WorkspaceResourceEntry>? resources,
    List<MaterialGraphResourceDocument>? materialGraphs,
    List<MathGraphResourceDocument>? mathGraphs,
    List<ImageResourceDocument>? images,
    List<SvgResourceDocument>? svgs,
  }) {
    return WorkspaceProjectDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      rootFolderId: rootFolderId ?? this.rootFolderId,
      resources: resources ?? this.resources,
      materialGraphs: materialGraphs ?? this.materialGraphs,
      mathGraphs: mathGraphs ?? this.mathGraphs,
      images: images ?? this.images,
      svgs: svgs ?? this.svgs,
    );
  }

  factory WorkspaceProjectDocument.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceProjectDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceProjectDocumentToJson(this);
}

const Object _sentinel = Object();
