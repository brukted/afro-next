import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'material_node_definition.dart';

class MaterialGraphCatalog {
  MaterialGraphCatalog(this._idFactory);

  final IdFactory _idFactory;

  late final List<MaterialNodeDefinition> _definitions =
      <MaterialNodeDefinition>[
        MaterialNodeDefinition(
          schema: GraphNodeSchema(
            id: 'solid_color_node',
            label: 'Solid Color',
            description: 'Produces a constant RGBA color.',
            properties: [
              GraphPropertyDefinition(
                key: 'color',
                label: 'Color',
                valueType: GraphValueType.color,
                defaultValue: _color('#3DD6B0'),
              ),
              GraphPropertyDefinition(
                key: 'output',
                label: 'Output',
                valueType: GraphValueType.color,
                defaultValue: _color('#000000'),
                socketDirection: GraphSocketDirection.output,
              ),
            ],
          ),
          icon: Icons.palette_outlined,
          accentColor: _color('#3DD6B0'),
        ),
        MaterialNodeDefinition(
          schema: GraphNodeSchema(
            id: 'mix_node',
            label: 'Mix',
            description: 'Blends two inputs together using a configurable mode.',
            properties: const [
              GraphPropertyDefinition(
                key: 'foreground',
                label: 'Foreground',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.input,
              ),
              GraphPropertyDefinition(
                key: 'background',
                label: 'Background',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.input,
              ),
              GraphPropertyDefinition(
                key: 'mask',
                label: 'Mask',
                valueType: GraphValueType.scalar,
                defaultValue: 0.5,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'blendMode',
                label: 'Blend Mode',
                valueType: GraphValueType.enumChoice,
                defaultValue: 1,
                enumOptions: [
                  EnumChoiceOption(id: 'copy', label: 'Copy', value: 1),
                  EnumChoiceOption(id: 'multiply', label: 'Multiply', value: 2),
                  EnumChoiceOption(id: 'screen', label: 'Screen', value: 3),
                  EnumChoiceOption(id: 'overlay', label: 'Overlay', value: 4),
                  EnumChoiceOption(id: 'softLight', label: 'Soft Light', value: 6),
                ],
              ),
              GraphPropertyDefinition(
                key: 'alphaMode',
                label: 'Alpha Mode',
                valueType: GraphValueType.enumChoice,
                defaultValue: 0,
                enumOptions: [
                  EnumChoiceOption(id: 'background', label: 'Background', value: 0),
                  EnumChoiceOption(id: 'foreground', label: 'Foreground', value: 1),
                  EnumChoiceOption(id: 'average', label: 'Average', value: 4),
                ],
              ),
              GraphPropertyDefinition(
                key: 'alpha',
                label: 'Alpha',
                valueType: GraphValueType.scalar,
                defaultValue: 1.0,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'output',
                label: 'Output',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.output,
              ),
            ],
          ),
          icon: Icons.merge_type_outlined,
          accentColor: _color('#7D67FF'),
        ),
        MaterialNodeDefinition(
          schema: GraphNodeSchema(
            id: 'channel_select_node',
            label: 'Channel Select',
            description: 'Rebuilds RGBA channels from two input colors.',
            properties: const [
              GraphPropertyDefinition(
                key: 'input1',
                label: 'Input 1',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.input,
              ),
              GraphPropertyDefinition(
                key: 'input2',
                label: 'Input 2',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.input,
              ),
              GraphPropertyDefinition(
                key: 'channelRed',
                label: 'Red Channel',
                valueType: GraphValueType.enumChoice,
                defaultValue: 0,
                enumOptions: [
                  EnumChoiceOption(id: 'r1', label: 'Red 1', value: 0),
                  EnumChoiceOption(id: 'g1', label: 'Green 1', value: 1),
                  EnumChoiceOption(id: 'b1', label: 'Blue 1', value: 2),
                  EnumChoiceOption(id: 'a1', label: 'Alpha 1', value: 3),
                  EnumChoiceOption(id: 'r2', label: 'Red 2', value: 4),
                  EnumChoiceOption(id: 'g2', label: 'Green 2', value: 5),
                  EnumChoiceOption(id: 'b2', label: 'Blue 2', value: 6),
                  EnumChoiceOption(id: 'a2', label: 'Alpha 2', value: 7),
                ],
              ),
              GraphPropertyDefinition(
                key: 'channelGreen',
                label: 'Green Channel',
                valueType: GraphValueType.enumChoice,
                defaultValue: 1,
                enumOptions: [
                  EnumChoiceOption(id: 'r1', label: 'Red 1', value: 0),
                  EnumChoiceOption(id: 'g1', label: 'Green 1', value: 1),
                  EnumChoiceOption(id: 'b1', label: 'Blue 1', value: 2),
                  EnumChoiceOption(id: 'a1', label: 'Alpha 1', value: 3),
                  EnumChoiceOption(id: 'r2', label: 'Red 2', value: 4),
                  EnumChoiceOption(id: 'g2', label: 'Green 2', value: 5),
                  EnumChoiceOption(id: 'b2', label: 'Blue 2', value: 6),
                  EnumChoiceOption(id: 'a2', label: 'Alpha 2', value: 7),
                ],
              ),
              GraphPropertyDefinition(
                key: 'channelBlue',
                label: 'Blue Channel',
                valueType: GraphValueType.enumChoice,
                defaultValue: 2,
                enumOptions: [
                  EnumChoiceOption(id: 'r1', label: 'Red 1', value: 0),
                  EnumChoiceOption(id: 'g1', label: 'Green 1', value: 1),
                  EnumChoiceOption(id: 'b1', label: 'Blue 1', value: 2),
                  EnumChoiceOption(id: 'a1', label: 'Alpha 1', value: 3),
                  EnumChoiceOption(id: 'r2', label: 'Red 2', value: 4),
                  EnumChoiceOption(id: 'g2', label: 'Green 2', value: 5),
                  EnumChoiceOption(id: 'b2', label: 'Blue 2', value: 6),
                  EnumChoiceOption(id: 'a2', label: 'Alpha 2', value: 7),
                ],
              ),
              GraphPropertyDefinition(
                key: 'channelAlpha',
                label: 'Alpha Channel',
                valueType: GraphValueType.enumChoice,
                defaultValue: 3,
                enumOptions: [
                  EnumChoiceOption(id: 'r1', label: 'Red 1', value: 0),
                  EnumChoiceOption(id: 'g1', label: 'Green 1', value: 1),
                  EnumChoiceOption(id: 'b1', label: 'Blue 1', value: 2),
                  EnumChoiceOption(id: 'a1', label: 'Alpha 1', value: 3),
                  EnumChoiceOption(id: 'r2', label: 'Red 2', value: 4),
                  EnumChoiceOption(id: 'g2', label: 'Green 2', value: 5),
                  EnumChoiceOption(id: 'b2', label: 'Blue 2', value: 6),
                  EnumChoiceOption(id: 'a2', label: 'Alpha 2', value: 7),
                ],
              ),
              GraphPropertyDefinition(
                key: 'output',
                label: 'Output',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.output,
              ),
            ],
          ),
          icon: Icons.tune_outlined,
          accentColor: _color('#FFB053'),
        ),
        MaterialNodeDefinition(
          schema: GraphNodeSchema(
            id: 'circle_node',
            label: 'Circle',
            description: 'Generates a circular shape mask.',
            properties: const [
              GraphPropertyDefinition(
                key: 'radius',
                label: 'Radius',
                valueType: GraphValueType.scalar,
                defaultValue: 0.5,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'outline',
                label: 'Outline',
                valueType: GraphValueType.scalar,
                defaultValue: 0.0,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'width',
                label: 'Width',
                valueType: GraphValueType.scalar,
                defaultValue: 0.5,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'height',
                label: 'Height',
                valueType: GraphValueType.scalar,
                defaultValue: 0.5,
                min: 0,
                max: 1,
              ),
              GraphPropertyDefinition(
                key: 'output',
                label: 'Output',
                valueType: GraphValueType.color,
                defaultValue: 0,
                socketDirection: GraphSocketDirection.output,
              ),
            ],
          ),
          icon: Icons.circle_outlined,
          accentColor: _color('#F06C8F'),
        ),
      ];

  List<MaterialNodeDefinition> get definitions => _definitions;

  MaterialNodeDefinition definitionById(String id) {
    return _definitions.firstWhere((definition) => definition.id == id);
  }

  GraphNodeDocument instantiateNode({
    required String definitionId,
    required vmath.Vector2 position,
    int sequence = 1,
  }) {
    final definition = definitionById(definitionId);
    return GraphNodeDocument(
      id: _idFactory.next(),
      definitionId: definition.id,
      name: '${definition.label} $sequence',
      position: position,
      properties: definition.properties.map((propertyDefinition) {
        return GraphNodePropertyData(
          id: _idFactory.next(),
          definitionKey: propertyDefinition.key,
          value: _wrapDefaultValue(propertyDefinition),
        );
      }).toList(growable: false),
    );
  }

  GraphDocument createStarterGraph({required String name}) {
    final solidColor = instantiateNode(
      definitionId: 'solid_color_node',
      position: vmath.Vector2(520, 520),
    );
    final circle = instantiateNode(
      definitionId: 'circle_node',
      position: vmath.Vector2(520, 790),
    );
    final mix = instantiateNode(
      definitionId: 'mix_node',
      position: vmath.Vector2(860, 630),
    );
    final channelSelect = instantiateNode(
      definitionId: 'channel_select_node',
      position: vmath.Vector2(1210, 630),
    );

    final links = <GraphLinkDocument>[
      _connect(
        fromNode: solidColor,
        fromKey: 'output',
        toNode: mix,
        toKey: 'foreground',
      ),
      _connect(
        fromNode: circle,
        fromKey: 'output',
        toNode: mix,
        toKey: 'background',
      ),
      _connect(
        fromNode: mix,
        fromKey: 'output',
        toNode: channelSelect,
        toKey: 'input1',
      ),
      _connect(
        fromNode: solidColor,
        fromKey: 'output',
        toNode: channelSelect,
        toKey: 'input2',
      ),
    ];

    return GraphDocument(
      id: _idFactory.next(),
      name: name,
      nodes: [solidColor, circle, mix, channelSelect],
      links: links,
    );
  }

  GraphLinkDocument _connect({
    required GraphNodeDocument fromNode,
    required String fromKey,
    required GraphNodeDocument toNode,
    required String toKey,
  }) {
    return GraphLinkDocument(
      id: _idFactory.next(),
      fromNodeId: fromNode.id,
      fromPropertyId: fromNode.propertyByDefinitionKey(fromKey)!.id,
      toNodeId: toNode.id,
      toPropertyId: toNode.propertyByDefinitionKey(toKey)!.id,
    );
  }

  GraphValueData _wrapDefaultValue(GraphPropertyDefinition definition) {
    switch (definition.valueType) {
      case GraphValueType.scalar:
        return GraphValueData.scalar((definition.defaultValue as num).toDouble());
      case GraphValueType.enumChoice:
        return GraphValueData.enumChoice(definition.defaultValue as int);
      case GraphValueType.color:
        final color = definition.defaultValue;
        if (color is vmath.Vector4) {
          return GraphValueData.color(color.clone());
        }
        return GraphValueData.color(vmath.Vector4.zero());
    }
  }

  static vmath.Vector4 _color(String value) {
    final result = vmath.Vector4.zero();
    vmath.Colors.fromHexString(value, result);
    result.w = 1;
    return result;
  }
}
