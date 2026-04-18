import 'package:flutter/material.dart';

import '../../shared/ids/id_factory.dart';
import 'models/material_graph_models.dart';

class MaterialGraphCatalog {
  MaterialGraphCatalog(this._idFactory);

  final IdFactory _idFactory;

  late final List<GraphNodeDefinition> _definitions = <GraphNodeDefinition>[
    GraphNodeDefinition(
      id: 'solid_color_node',
      label: 'Solid Color',
      description: 'Produces a constant RGBA color.',
      icon: Icons.palette_outlined,
      accentColor: const Color(0xFF3DD6B0),
      properties: const [
        NodePropertyDefinition(
          key: 'color',
          label: 'Color',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF3DD6B0),
        ),
        NodePropertyDefinition(
          key: 'output',
          label: 'Output',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.output,
        ),
      ],
    ),
    GraphNodeDefinition(
      id: 'mix_node',
      label: 'Mix',
      description: 'Blends two inputs together using a configurable mode.',
      icon: Icons.merge_type_outlined,
      accentColor: const Color(0xFF7D67FF),
      properties: const [
        NodePropertyDefinition(
          key: 'foreground',
          label: 'Foreground',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFFFFFFFF),
          socketDirection: GraphSocketDirection.input,
        ),
        NodePropertyDefinition(
          key: 'background',
          label: 'Background',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.input,
        ),
        NodePropertyDefinition(
          key: 'mask',
          label: 'Mask',
          valueType: GraphValueType.scalar,
          defaultValue: 0.5,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'blendMode',
          label: 'Blend Mode',
          valueType: GraphValueType.enumChoice,
          defaultValue: 0,
          enumOptions: [
            EnumChoiceOption(id: 'copy', label: 'Copy', value: 1),
            EnumChoiceOption(id: 'multiply', label: 'Multiply', value: 2),
            EnumChoiceOption(id: 'screen', label: 'Screen', value: 3),
            EnumChoiceOption(id: 'overlay', label: 'Overlay', value: 4),
            EnumChoiceOption(id: 'softLight', label: 'Soft Light', value: 6),
          ],
        ),
        NodePropertyDefinition(
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
        NodePropertyDefinition(
          key: 'alpha',
          label: 'Alpha',
          valueType: GraphValueType.scalar,
          defaultValue: 1.0,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'output',
          label: 'Output',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.output,
        ),
      ],
    ),
    GraphNodeDefinition(
      id: 'channel_select_node',
      label: 'Channel Select',
      description: 'Rebuilds RGBA channels from two input colors.',
      icon: Icons.tune_outlined,
      accentColor: const Color(0xFFFFB053),
      properties: const [
        NodePropertyDefinition(
          key: 'input1',
          label: 'Input 1',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFFFFFFFF),
          socketDirection: GraphSocketDirection.input,
        ),
        NodePropertyDefinition(
          key: 'input2',
          label: 'Input 2',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.input,
        ),
        NodePropertyDefinition(
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
        NodePropertyDefinition(
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
        NodePropertyDefinition(
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
        NodePropertyDefinition(
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
        NodePropertyDefinition(
          key: 'output',
          label: 'Output',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.output,
        ),
      ],
    ),
    GraphNodeDefinition(
      id: 'circle_node',
      label: 'Circle',
      description: 'Generates a circular shape mask.',
      icon: Icons.circle_outlined,
      accentColor: const Color(0xFFF06C8F),
      properties: const [
        NodePropertyDefinition(
          key: 'radius',
          label: 'Radius',
          valueType: GraphValueType.scalar,
          defaultValue: 0.5,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'outline',
          label: 'Outline',
          valueType: GraphValueType.scalar,
          defaultValue: 0.0,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'width',
          label: 'Width',
          valueType: GraphValueType.scalar,
          defaultValue: 0.5,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'height',
          label: 'Height',
          valueType: GraphValueType.scalar,
          defaultValue: 0.5,
          min: 0,
          max: 1,
        ),
        NodePropertyDefinition(
          key: 'output',
          label: 'Output',
          valueType: GraphValueType.color,
          defaultValue: Color(0xFF000000),
          socketDirection: GraphSocketDirection.output,
        ),
      ],
    ),
  ];

  List<GraphNodeDefinition> get definitions => _definitions;

  GraphNodeDefinition definitionById(String id) {
    return _definitions.firstWhere((definition) => definition.id == id);
  }

  GraphNodeInstance instantiateNode({
    required String definitionId,
    required Offset position,
    int sequence = 1,
  }) {
    final definition = definitionById(definitionId);
    return GraphNodeInstance(
      id: _idFactory.next(),
      definitionId: definition.id,
      name: '${definition.label} $sequence',
      position: position,
      properties: definition.properties.map((propertyDefinition) {
        return GraphNodeProperty(
          id: _idFactory.next(),
          definitionKey: propertyDefinition.key,
          value: propertyDefinition.defaultValue,
        );
      }).toList(growable: false),
    );
  }

  WorkspaceDocument createInitialWorkspace() {
    final solidColor = instantiateNode(
      definitionId: 'solid_color_node',
      position: const Offset(120, 160),
    );
    final circle = instantiateNode(
      definitionId: 'circle_node',
      position: const Offset(120, 420),
    );
    final mix = instantiateNode(
      definitionId: 'mix_node',
      position: const Offset(470, 260),
    );
    final channelSelect = instantiateNode(
      definitionId: 'channel_select_node',
      position: const Offset(870, 260),
    );

    final links = <MaterialGraphLink>[
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

    return WorkspaceDocument(
      id: _idFactory.next(),
      name: 'Eyecandy Workspace',
      graphs: [
        MaterialGraphDocument(
          id: _idFactory.next(),
          name: 'Material Graph 1',
          nodes: [solidColor, circle, mix, channelSelect],
          links: links,
        ),
      ],
    );
  }

  MaterialGraphLink _connect({
    required GraphNodeInstance fromNode,
    required String fromKey,
    required GraphNodeInstance toNode,
    required String toKey,
  }) {
    return MaterialGraphLink(
      id: _idFactory.next(),
      fromNodeId: fromNode.id,
      fromPropertyId: fromNode.propertyByDefinitionKey(fromKey)!.id,
      toNodeId: toNode.id,
      toPropertyId: toNode.propertyByDefinitionKey(toKey)!.id,
    );
  }
}
