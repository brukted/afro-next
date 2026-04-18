import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'material_node_definition.dart';

class MaterialGraphCatalog {
  MaterialGraphCatalog(this._idFactory);

  final IdFactory _idFactory;

  static const List<EnumChoiceOption> _mixBlendModes = [
    EnumChoiceOption(id: 'add_sub', label: 'Add Sub', value: 0),
    EnumChoiceOption(id: 'copy', label: 'Copy', value: 1),
    EnumChoiceOption(id: 'multiply', label: 'Multiply', value: 2),
    EnumChoiceOption(id: 'screen', label: 'Screen', value: 3),
    EnumChoiceOption(id: 'overlay', label: 'Overlay', value: 4),
    EnumChoiceOption(id: 'hard_light', label: 'Hard Light', value: 5),
    EnumChoiceOption(id: 'soft_light', label: 'Soft Light', value: 6),
    EnumChoiceOption(id: 'color_dodge', label: 'Color Dodge', value: 7),
    EnumChoiceOption(id: 'linear_dodge', label: 'Linear Dodge', value: 8),
    EnumChoiceOption(id: 'color_burn', label: 'Color Burn', value: 9),
    EnumChoiceOption(id: 'linear_burn', label: 'Linear Burn', value: 10),
    EnumChoiceOption(id: 'vivid_light', label: 'Vivid Light', value: 11),
    EnumChoiceOption(id: 'divide', label: 'Divide', value: 12),
    EnumChoiceOption(id: 'subtract', label: 'Subtract', value: 13),
    EnumChoiceOption(id: 'difference', label: 'Difference', value: 14),
    EnumChoiceOption(id: 'darken', label: 'Darken', value: 15),
    EnumChoiceOption(id: 'lighten', label: 'Lighten', value: 16),
    EnumChoiceOption(id: 'hue', label: 'Hue', value: 17),
    EnumChoiceOption(id: 'saturation', label: 'Saturation', value: 18),
    EnumChoiceOption(id: 'color', label: 'Color', value: 19),
    EnumChoiceOption(id: 'luminosity', label: 'Luminosity', value: 20),
    EnumChoiceOption(id: 'linear_light', label: 'Linear Light', value: 21),
    EnumChoiceOption(id: 'pin_light', label: 'Pin Light', value: 22),
    EnumChoiceOption(id: 'hard_mix', label: 'Hard Mix', value: 23),
    EnumChoiceOption(id: 'exclusion', label: 'Exclusion', value: 24),
  ];

  static const List<EnumChoiceOption> _mixAlphaModes = [
    EnumChoiceOption(id: 'background', label: 'Background', value: 0),
    EnumChoiceOption(id: 'foreground', label: 'Foreground', value: 1),
    EnumChoiceOption(id: 'min', label: 'Min', value: 2),
    EnumChoiceOption(id: 'max', label: 'Max', value: 3),
    EnumChoiceOption(id: 'average', label: 'Average', value: 4),
    EnumChoiceOption(id: 'add', label: 'Add', value: 5),
  ];

  static const List<EnumChoiceOption> _channelSelectOptions = [
    EnumChoiceOption(id: 'red_1', label: 'Red 1', value: 0),
    EnumChoiceOption(id: 'green_1', label: 'Green 1', value: 1),
    EnumChoiceOption(id: 'blue_1', label: 'Blue 1', value: 2),
    EnumChoiceOption(id: 'alpha_1', label: 'Alpha 1', value: 3),
    EnumChoiceOption(id: 'red_2', label: 'Red 2', value: 4),
    EnumChoiceOption(id: 'green_2', label: 'Green 2', value: 5),
    EnumChoiceOption(id: 'blue_2', label: 'Blue 2', value: 6),
    EnumChoiceOption(id: 'alpha_2', label: 'Alpha 2', value: 7),
  ];

  late final List<MaterialNodeDefinition>
  _definitions = <MaterialNodeDefinition>[
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'solid_color_node',
        label: 'Solid Color',
        description: 'Produces a constant RGBA color.',
        properties: [
          GraphPropertyDefinition(
            key: 'color',
            label: 'Color',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
          ),
          GraphPropertyDefinition(
            key: '_output',
            label: 'Output',
            description: 'Empty desc',
            propertyType: GraphPropertyType.output,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _black(),
          ),
        ],
      ),
      icon: Icons.palette_outlined,
      accentColor: _color('#3DD6B0'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/uniform_color.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'mix_node',
        label: 'Mix Node',
        description: 'Blends two inputs together using a configurable mode.',
        properties: [
          GraphPropertyDefinition(
            key: 'Foreground',
            label: 'Foreground',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
          ),
          GraphPropertyDefinition(
            key: 'Background',
            label: 'Background',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
          ),
          GraphPropertyDefinition(
            key: 'Mask',
            label: 'Mask',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.color,
            defaultValue: 0.5,
          ),
          GraphPropertyDefinition(
            key: 'blendMode',
            label: 'Blend Mode',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _mixBlendModes,
          ),
          GraphPropertyDefinition(
            key: 'alphaMode',
            label: 'Alpha Mode',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _mixAlphaModes,
          ),
          GraphPropertyDefinition(
            key: 'alpha',
            label: 'Alpha',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 1.0,
            min: 0,
            max: 1,
          ),
          GraphPropertyDefinition(
            key: '_output',
            label: 'Output',
            description: 'Empty desc',
            propertyType: GraphPropertyType.output,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _black(),
          ),
        ],
      ),
      icon: Icons.merge_type_outlined,
      accentColor: _color('#7D67FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/blend.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'channel_select_node',
        label: 'Channel Select',
        description: 'Rebuilds RGBA channels from two input colors.',
        properties: [
          GraphPropertyDefinition(
            key: 'input1',
            label: 'Input 1',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
          ),
          GraphPropertyDefinition(
            key: 'input2',
            label: 'Input 2',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
          ),
          GraphPropertyDefinition(
            key: 'channel_red',
            label: 'Red Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _channelSelectOptions,
          ),
          GraphPropertyDefinition(
            key: 'channel_green',
            label: 'Green Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 1,
            enumOptions: _channelSelectOptions,
          ),
          GraphPropertyDefinition(
            key: 'channel_blue',
            label: 'Blue Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 2,
            enumOptions: _channelSelectOptions,
          ),
          GraphPropertyDefinition(
            key: 'channel_alpha',
            label: 'Alpha Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 3,
            enumOptions: _channelSelectOptions,
          ),
          GraphPropertyDefinition(
            key: '_output',
            label: 'Output',
            description: 'Empty desc',
            propertyType: GraphPropertyType.output,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _black(),
          ),
        ],
      ),
      icon: Icons.tune_outlined,
      accentColor: _color('#FFB053'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/channel_select.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'circle_node',
        label: 'Circle Node',
        description: 'Generates a circular shape mask.',
        properties: [
          GraphPropertyDefinition(
            key: 'radius',
            label: 'Radius',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.5,
            min: 0,
            max: 1,
          ),
          GraphPropertyDefinition(
            key: 'outline',
            label: 'Outline',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.0,
            min: 0,
            max: 1,
          ),
          GraphPropertyDefinition(
            key: 'width',
            label: 'Width',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.1,
            min: 0,
            max: 1,
          ),
          GraphPropertyDefinition(
            key: 'height',
            label: 'Height',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.1,
            min: 0,
            max: 1,
          ),
          GraphPropertyDefinition(
            key: '_output',
            label: 'Output',
            description: 'Empty desc',
            propertyType: GraphPropertyType.output,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _black(),
          ),
        ],
      ),
      icon: Icons.circle_outlined,
      accentColor: _color('#F06C8F'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/circle.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'curve_demo_node',
        label: 'Curve Demo',
        description: 'Exposes a multi-channel bezier color curve editor.',
        properties: [
          GraphPropertyDefinition(
            key: 'curve',
            label: 'Curve',
            description: 'Editable luminance and RGBA bezier response curves.',
            propertyType: GraphPropertyType.descriptor,
            socket: false,
            valueType: GraphValueType.colorBezierCurve,
            valueUnit: GraphValueUnit.none,
            defaultValue: GraphColorCurveData.identity(),
          ),
          GraphPropertyDefinition(
            key: '_output',
            label: 'Output',
            description: 'Empty desc',
            propertyType: GraphPropertyType.output,
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _black(),
          ),
        ],
      ),
      icon: Icons.timeline_outlined,
      accentColor: _color('#8FA8FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(shaderAssetId: null),
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
      properties: definition.properties
          .map((propertyDefinition) {
            return GraphNodePropertyData(
              id: _idFactory.next(),
              definitionKey: propertyDefinition.key,
              value: _wrapDefaultValue(propertyDefinition),
            );
          })
          .toList(growable: false),
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
    final curveDemo = instantiateNode(
      definitionId: 'curve_demo_node',
      position: vmath.Vector2(1530, 630),
    );

    final links = <GraphLinkDocument>[
      _connect(
        fromNode: solidColor,
        fromKey: '_output',
        toNode: mix,
        toKey: 'Foreground',
      ),
      _connect(
        fromNode: circle,
        fromKey: '_output',
        toNode: mix,
        toKey: 'Background',
      ),
      _connect(
        fromNode: mix,
        fromKey: '_output',
        toNode: channelSelect,
        toKey: 'input1',
      ),
      _connect(
        fromNode: solidColor,
        fromKey: '_output',
        toNode: channelSelect,
        toKey: 'input2',
      ),
    ];

    return GraphDocument(
      id: _idFactory.next(),
      name: name,
      nodes: [solidColor, circle, mix, channelSelect, curveDemo],
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
      case GraphValueType.integer:
        return GraphValueData.integer((definition.defaultValue as num).toInt());
      case GraphValueType.integer2:
        return GraphValueData.integer2(asIntVector(definition.defaultValue));
      case GraphValueType.integer3:
        return GraphValueData.integer3(asIntVector(definition.defaultValue));
      case GraphValueType.integer4:
        return GraphValueData.integer4(asIntVector(definition.defaultValue));
      case GraphValueType.float:
        return GraphValueData.float(
          (definition.defaultValue as num).toDouble(),
        );
      case GraphValueType.float2:
        return GraphValueData.float2(asVector2(definition.defaultValue));
      case GraphValueType.float3:
        return GraphValueData.float3(asVector3(definition.defaultValue));
      case GraphValueType.float4:
        return GraphValueData.float4(asVector4(definition.defaultValue));
      case GraphValueType.stringValue:
        return GraphValueData.stringValue(definition.defaultValue as String);
      case GraphValueType.boolean:
        return GraphValueData.boolean(definition.defaultValue as bool);
      case GraphValueType.enumChoice:
        return GraphValueData.enumChoice(definition.defaultValue as int);
      case GraphValueType.colorBezierCurve:
        return GraphValueData.colorCurve(asColorCurve(definition.defaultValue));
    }
  }

  static vmath.Vector4 _color(String value) {
    final result = vmath.Vector4.zero();
    vmath.Colors.fromHexString(value, result);
    result.w = 1;
    return result;
  }

  static vmath.Vector4 _white() => vmath.Vector4(1, 1, 1, 1);

  static vmath.Vector4 _black() => vmath.Vector4.zero();
}
