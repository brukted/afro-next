// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkspaceResourceEntry _$WorkspaceResourceEntryFromJson(
  Map<String, dynamic> json,
) => WorkspaceResourceEntry(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: $enumDecode(_$WorkspaceResourceKindEnumMap, json['kind']),
  parentId: json['parentId'] as String?,
  documentId: json['documentId'] as String?,
);

Map<String, dynamic> _$WorkspaceResourceEntryToJson(
  WorkspaceResourceEntry instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'kind': _$WorkspaceResourceKindEnumMap[instance.kind]!,
  'parentId': instance.parentId,
  'documentId': instance.documentId,
};

const _$WorkspaceResourceKindEnumMap = {
  WorkspaceResourceKind.folder: 'folder',
  WorkspaceResourceKind.materialGraph: 'materialGraph',
  WorkspaceResourceKind.mathGraph: 'mathGraph',
  WorkspaceResourceKind.image: 'image',
  WorkspaceResourceKind.svg: 'svg',
};

MaterialGraphResourceDocument _$MaterialGraphResourceDocumentFromJson(
  Map<String, dynamic> json,
) => MaterialGraphResourceDocument(
  id: json['id'] as String,
  graph: GraphDocument.fromJson(json['graph'] as Map<String, dynamic>),
  outputSizeSettings: json['outputSizeSettings'] == null
      ? const MaterialOutputSizeSettings()
      : MaterialOutputSizeSettings.fromJson(
          json['outputSizeSettings'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$MaterialGraphResourceDocumentToJson(
  MaterialGraphResourceDocument instance,
) => <String, dynamic>{
  'id': instance.id,
  'graph': instance.graph.toJson(),
  'outputSizeSettings': instance.outputSizeSettings.toJson(),
};

MathGraphResourceDocument _$MathGraphResourceDocumentFromJson(
  Map<String, dynamic> json,
) => MathGraphResourceDocument(
  id: json['id'] as String,
  graph: GraphDocument.fromJson(json['graph'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MathGraphResourceDocumentToJson(
  MathGraphResourceDocument instance,
) => <String, dynamic>{'id': instance.id, 'graph': instance.graph.toJson()};

ImageResourceDocument _$ImageResourceDocumentFromJson(
  Map<String, dynamic> json,
) => ImageResourceDocument(
  id: json['id'] as String,
  sourceName: json['sourceName'] as String,
  encodedBytesBase64: json['encodedBytesBase64'] as String,
  mimeType: json['mimeType'] as String?,
);

Map<String, dynamic> _$ImageResourceDocumentToJson(
  ImageResourceDocument instance,
) => <String, dynamic>{
  'id': instance.id,
  'sourceName': instance.sourceName,
  'encodedBytesBase64': instance.encodedBytesBase64,
  'mimeType': instance.mimeType,
};

SvgResourceDocument _$SvgResourceDocumentFromJson(Map<String, dynamic> json) =>
    SvgResourceDocument(
      id: json['id'] as String,
      sourceName: json['sourceName'] as String,
      svgText: json['svgText'] as String,
    );

Map<String, dynamic> _$SvgResourceDocumentToJson(
  SvgResourceDocument instance,
) => <String, dynamic>{
  'id': instance.id,
  'sourceName': instance.sourceName,
  'svgText': instance.svgText,
};

WorkspaceProjectDocument _$WorkspaceProjectDocumentFromJson(
  Map<String, dynamic> json,
) => WorkspaceProjectDocument(
  id: json['id'] as String,
  name: json['name'] as String,
  rootFolderId: json['rootFolderId'] as String,
  resources: (json['resources'] as List<dynamic>)
      .map((e) => WorkspaceResourceEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  materialGraphs: (json['materialGraphs'] as List<dynamic>)
      .map(
        (e) =>
            MaterialGraphResourceDocument.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  mathGraphs: (json['mathGraphs'] as List<dynamic>)
      .map((e) => MathGraphResourceDocument.fromJson(e as Map<String, dynamic>))
      .toList(),
  images:
      (json['images'] as List<dynamic>?)
          ?.map(
            (e) => ImageResourceDocument.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ImageResourceDocument>[],
  svgs:
      (json['svgs'] as List<dynamic>?)
          ?.map((e) => SvgResourceDocument.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SvgResourceDocument>[],
);

Map<String, dynamic> _$WorkspaceProjectDocumentToJson(
  WorkspaceProjectDocument instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'rootFolderId': instance.rootFolderId,
  'resources': instance.resources.map((e) => e.toJson()).toList(),
  'materialGraphs': instance.materialGraphs.map((e) => e.toJson()).toList(),
  'mathGraphs': instance.mathGraphs.map((e) => e.toJson()).toList(),
  'images': instance.images.map((e) => e.toJson()).toList(),
  'svgs': instance.svgs.map((e) => e.toJson()).toList(),
};
