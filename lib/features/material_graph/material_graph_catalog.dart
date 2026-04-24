import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vmath;

import '../../shared/ids/id_factory.dart';
import '../graph/models/graph_models.dart';
import '../graph/models/graph_schema.dart';
import 'material_node_definition.dart';
import 'material_output_size.dart';

const String materialTexelGraphNodeDefinitionId = 'texel_graph_node';
const String materialTexelGraphResourcePropertyKey = 'graph';

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

  static const List<EnumChoiceOption> _fxBlendModes = [
    EnumChoiceOption(id: 'alpha_blend', label: 'Alpha Blend', value: 0),
    EnumChoiceOption(id: 'add', label: 'Add', value: 1),
    EnumChoiceOption(id: 'max', label: 'Max', value: 2),
    EnumChoiceOption(id: 'add_sub', label: 'Add Sub', value: 3),
  ];

  late final List<MaterialNodeDefinition>
  _definitions = <MaterialNodeDefinition>[
    ..._inputNodes(),
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
            socket: true,
            valueType: GraphValueType.float4,
            valueUnit: GraphValueUnit.color,
            defaultValue: _white(),
            socketTransport: GraphSocketTransport.value,
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
            socketTransport: GraphSocketTransport.texture,
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
            socketTransport: GraphSocketTransport.texture,
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
            socketTransport: GraphSocketTransport.texture,
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
            socketTransport: GraphSocketTransport.texture,
          ),
          GraphPropertyDefinition(
            key: 'blendMode',
            label: 'Blend Mode',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _mixBlendModes,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'alphaMode',
            label: 'Alpha Mode',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _mixAlphaModes,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'alpha',
            label: 'Alpha',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 1.0,
            min: 0,
            max: 1,
            socketTransport: GraphSocketTransport.value,
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
            socketTransport: GraphSocketTransport.texture,
          ),
        ],
      ),
      icon: Icons.merge_type_outlined,
      accentColor: _color('#7D67FF'),
      primaryInputPropertyKey: 'Background',
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
            socketTransport: GraphSocketTransport.texture,
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
            socketTransport: GraphSocketTransport.texture,
          ),
          GraphPropertyDefinition(
            key: 'channel_red',
            label: 'Red Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0,
            enumOptions: _channelSelectOptions,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'channel_green',
            label: 'Green Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 1,
            enumOptions: _channelSelectOptions,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'channel_blue',
            label: 'Blue Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 2,
            enumOptions: _channelSelectOptions,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'channel_alpha',
            label: 'Alpha Channel',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.enumChoice,
            valueUnit: GraphValueUnit.none,
            defaultValue: 3,
            enumOptions: _channelSelectOptions,
            socketTransport: GraphSocketTransport.value,
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
            socketTransport: GraphSocketTransport.texture,
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
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.5,
            min: 0,
            max: 1,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'outline',
            label: 'Outline',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.0,
            min: 0,
            max: 1,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'width',
            label: 'Width',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.1,
            min: 0,
            max: 1,
            socketTransport: GraphSocketTransport.value,
          ),
          GraphPropertyDefinition(
            key: 'height',
            label: 'Height',
            description: 'Empty desc',
            propertyType: GraphPropertyType.input,
            socket: true,
            valueType: GraphValueType.float,
            valueUnit: GraphValueUnit.none,
            defaultValue: 0.1,
            min: 0,
            max: 1,
            socketTransport: GraphSocketTransport.value,
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
            socketTransport: GraphSocketTransport.texture,
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
        id: 'image_node',
        label: 'Image',
        description:
            'Loads a workspace image resource into the material graph.',
        properties: [
          _resourceDescriptorInput(
            'resource',
            'Image Resource',
            bindingKey: 'MainTex',
            resourceKinds: const [GraphResourceKind.image],
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.image_search_outlined,
      accentColor: _color('#6FB7FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/image-basic.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'svg_node',
        label: 'SVG',
        description: 'Loads a workspace SVG resource into the material graph.',
        properties: [
          _resourceDescriptorInput(
            'resource',
            'SVG Resource',
            bindingKey: 'MainTex',
            resourceKinds: const [GraphResourceKind.svg],
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.polyline_outlined,
      accentColor: _color('#7ED7B5'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/image-basic.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'text_node',
        label: 'Text',
        description:
            'Renders styled text to a texture using a system font family name.',
        properties: [
          _textDescriptorInput(
            'content',
            'Text Content',
            bindingKey: 'MainTex',
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.text_fields_outlined,
      accentColor: _color('#F3B574'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/image-basic.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: materialTexelGraphNodeDefinitionId,
        label: 'Texel Graph',
        description:
            'Runs a referenced math graph per pixel and exposes its parameters as node inputs.',
        properties: [
          GraphPropertyDefinition(
            key: materialTexelGraphResourcePropertyKey,
            label: 'Math Graph',
            description: 'Select a workspace math graph to run per pixel.',
            propertyType: GraphPropertyType.descriptor,
            socket: false,
            valueType: GraphValueType.workspaceResource,
            valueUnit: GraphValueUnit.path,
            defaultValue: '',
            resourceKinds: const [GraphResourceKind.mathGraph],
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.auto_awesome_motion_outlined,
      accentColor: _color('#8D9CFF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(shaderAssetId: null),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'gamma_node',
        label: 'Gamma',
        description: 'Applies gamma correction to the main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'gamma',
            'Gamma',
            defaultValue: 2.2,
            min: 0.01,
            max: 8,
            step: 0.05,
            valueUnit: GraphValueUnit.power2,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.exposure_outlined,
      accentColor: _color('#F6C15A'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/gamma.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'levels_node',
        label: 'Levels',
        description: 'Adjusts range and gamma-like mid values per channel.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _float3Input(
            'minValues',
            'Min Values',
            defaultValue: vmath.Vector3.zero(),
          ),
          _float3Input(
            'maxValues',
            'Max Values',
            defaultValue: vmath.Vector3(1, 1, 1),
          ),
          _float3Input(
            'midValues',
            'Mid Values',
            defaultValue: vmath.Vector3.all(0.5),
          ),
          _float2Input(
            'value',
            'Value Range',
            defaultValue: vmath.Vector2(0, 1),
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.equalizer_outlined,
      accentColor: _color('#A1C96A'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/levels.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'grayscaleconv_node',
        label: 'Grayscale Convert',
        description:
            'Converts color to grayscale using configurable channel weights.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _float4Input(
            'weight',
            'Weight',
            defaultValue: vmath.Vector4(1, 1, 1, 0),
            valueUnit: GraphValueUnit.color,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.filter_b_and_w_outlined,
      accentColor: _color('#C9CEDB'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/grayscaleconv.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'hsl_node',
        label: 'HSL',
        description: 'Adjusts hue, saturation, and lightness.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'hue',
            'Hue',
            defaultValue: 0.0,
            min: -6,
            max: 6,
            step: 0.05,
            valueUnit: GraphValueUnit.rotation,
          ),
          _floatInput(
            'saturation',
            'Saturation',
            defaultValue: 0.0,
            min: -1,
            max: 1,
            step: 0.01,
          ),
          _floatInput(
            'lightness',
            'Lightness',
            defaultValue: 0.0,
            min: -1,
            max: 1,
            step: 0.01,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.tune_outlined,
      accentColor: _color('#FF9D6E'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/hsl.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'invert_node',
        label: 'Invert',
        description: 'Inverts individual channels of the main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _boolInput('invertRed', 'Invert Red', defaultValue: true),
          _boolInput('invertGreen', 'Invert Green', defaultValue: true),
          _boolInput('invertBlue', 'Invert Blue', defaultValue: true),
          _boolInput('invertAlpha', 'Invert Alpha', defaultValue: false),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.invert_colors_outlined,
      accentColor: _color('#8AE0D1'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/invert.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'sharpen_node',
        label: 'Sharpen',
        description: 'Applies unsharp-mask sharpening to the main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'intensity',
            'Intensity',
            defaultValue: 1.0,
            min: 0,
            max: 8,
            step: 0.05,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.auto_fix_high_outlined,
      accentColor: _color('#F4B86C'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/sharpen.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'blur_node',
        label: 'Blur',
        description:
            'Applies a one-dimensional blur along the pixel-shape axis.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'intensity',
            'Intensity',
            defaultValue: 8.0,
            min: 0,
            max: 64,
            step: 1,
          ),
          _float2Input(
            'pixel_shape',
            'Pixel Shape',
            defaultValue: vmath.Vector2(1, 1),
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.blur_on_outlined,
      accentColor: _color('#8CC7FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/blur.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'motionblur_node',
        label: 'Motion Blur',
        description: 'Applies directional motion blur to the main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput('tx', 'Direction X', defaultValue: 1.0, step: 0.05),
          _floatInput('ty', 'Direction Y', defaultValue: 0.0, step: 0.05),
          _floatInput(
            'magnitude',
            'Magnitude',
            defaultValue: 8.0,
            min: 1,
            max: 64,
            step: 1,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.motion_photos_on_outlined,
      accentColor: _color('#88A9FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/motionblur.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'warp_node',
        label: 'Warp',
        description:
            'Warps the main texture using a normal-style warp texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _socketColorInput('Warp', 'Warp Texture'),
          _floatInput(
            'intensity',
            'Intensity',
            defaultValue: 1.0,
            min: -4,
            max: 4,
            step: 0.05,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.waterfall_chart_outlined,
      accentColor: _color('#7ED8F6'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/warp.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'warpdirectional_node',
        label: 'Warp Directional',
        description:
            'Warps the main texture using scalar direction and warp input.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _socketColorInput('Warp', 'Warp Texture'),
          _floatInput(
            'intensity',
            'Intensity',
            defaultValue: 1.0,
            min: -4,
            max: 4,
            step: 0.05,
          ),
          _floatInput(
            'angle',
            'Angle',
            defaultValue: 0.0,
            min: -6.283185307179586,
            max: 6.283185307179586,
            step: 0.05,
            valueUnit: GraphValueUnit.rotation,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.explore_outlined,
      accentColor: _color('#75D7B2'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/warpdirectional.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'normals_node',
        label: 'Normals',
        description: 'Builds a normal map from a height-like main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'intensity',
            'Intensity',
            defaultValue: 1.0,
            min: 0.01,
            max: 16,
            step: 0.05,
          ),
          _boolInput('directx', 'DirectX Green', defaultValue: false),
          _floatInput(
            'reduce',
            'Noise Reduce',
            defaultValue: 0.004,
            min: 0,
            max: 1,
            step: 0.001,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.landscape_outlined,
      accentColor: _color('#8FD98E'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/normals.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'emboss_node',
        label: 'Emboss',
        description:
            'Embosses the main texture using a synthetic light direction.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _floatInput(
            'azimuth',
            'Azimuth',
            defaultValue: 0.0,
            min: -6.283185307179586,
            max: 6.283185307179586,
            step: 0.05,
            valueUnit: GraphValueUnit.rotation,
          ),
          _floatInput(
            'elevation',
            'Elevation',
            defaultValue: 1.0,
            min: -1.5707963267948966,
            max: 1.5707963267948966,
            step: 0.05,
            valueUnit: GraphValueUnit.rotation,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.texture_outlined,
      accentColor: _color('#F1A673'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/emboss.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'fx_node',
        label: 'FX Blend',
        description: 'Applies the legacy two-input FX blend modes.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _socketColorInput('Background', 'Background'),
          _enumInput(
            'blendMode',
            'Blend Mode',
            defaultValue: 0,
            options: _fxBlendModes,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.auto_awesome_outlined,
      accentColor: _color('#B88CFF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/fx.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'gradientmap_node',
        label: 'Gradient Map',
        description:
            'Maps the main texture through a LUT texture and optional mask.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _socketGradientInput('ColorLUT', 'Color LUT'),
          _socketColorInput('Mask', 'Mask'),
          _boolInput('useMask', 'Use Mask', defaultValue: false),
          _boolInput('horizontal', 'Horizontal LUT', defaultValue: true),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.gradient_outlined,
      accentColor: _color('#FF8FC6'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/gradientmap.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'curve_node',
        label: 'Curve',
        description:
            'Applies luminance and RGB curve LUT adjustments to the main texture.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _curveDescriptorInput('curve', 'Curve', bindingKey: 'CurveLUT'),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.timeline_outlined,
      accentColor: _color('#8FA8FF'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/curve.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'occlusion_node',
        label: 'Occlusion',
        description:
            'Combines a blurred occlusion texture with the original input.',
        properties: [
          _socketColorInput('MainTex', 'Blurred Texture'),
          _socketColorInput('Original', 'Original'),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.layers_outlined,
      accentColor: _color('#A9BE7A'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/occlusion.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'transform_node',
        label: 'Transform',
        description: 'Transforms texture coordinates with matrix controls.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _float3x3Input(
            'rotation',
            'Rotation Matrix',
            defaultValue: _identityMatrix3(),
          ),
          _float3x3Input(
            'scale',
            'Scale Matrix',
            defaultValue: _identityMatrix3(),
          ),
          _float3Input(
            'translation',
            'Translation',
            defaultValue: vmath.Vector3.zero(),
            valueUnit: GraphValueUnit.position,
          ),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.open_in_full_outlined,
      accentColor: _color('#F7C56F'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/transform.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'bloom_node',
        label: 'Bloom',
        description: 'Combines the main texture with a bloom input.',
        properties: [
          _socketColorInput('MainTex', 'Main Texture'),
          _socketColorInput('Bloom', 'Bloom'),
          _outputColorProperty(),
        ],
      ),
      icon: Icons.wb_twilight_outlined,
      accentColor: _color('#FFD37D'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/bloom.frag',
      ),
    ),
    MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: 'uv_node',
        label: 'UV',
        description: 'Outputs the Afro UV test color.',
        properties: [_outputColorProperty()],
      ),
      icon: Icons.grid_on_outlined,
      accentColor: _color('#52CFF5'),
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/uv.frag',
      ),
    ),
  ].map(_decorateDefinition).toList(growable: false);

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
    final inputValueDefinition = definition.inputValuePropertyKey == null
        ? null
        : definition.propertyDefinition(definition.inputValuePropertyKey!);
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
      inputUnitId: inputValueDefinition?.valueUnit.name,
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
      nodes: [solidColor, circle, mix, channelSelect],
      links: links,
    );
  }

  List<MaterialNodeDefinition> _inputNodes() {
    return <MaterialNodeDefinition>[
      _valueInputNode(
        id: 'input_integer_node',
        label: 'Input Integer',
        description: 'Provides an integer graph input for material parameters.',
        icon: Icons.pin_outlined,
        accentColor: _color('#FFB053'),
        valueType: GraphValueType.integer,
        valueUnit: GraphValueUnit.none,
        defaultValue: 0,
      ),
      _valueInputNode(
        id: 'input_integer2_node',
        label: 'Input Integer2',
        description: 'Provides an ivec2 graph input for material parameters.',
        icon: Icons.grid_view_outlined,
        accentColor: _color('#FFB053'),
        valueType: GraphValueType.integer2,
        valueUnit: GraphValueUnit.none,
        defaultValue: const <int>[0, 0],
      ),
      _valueInputNode(
        id: 'input_integer3_node',
        label: 'Input Integer3',
        description: 'Provides an ivec3 graph input for material parameters.',
        icon: Icons.view_in_ar_outlined,
        accentColor: _color('#FFB053'),
        valueType: GraphValueType.integer3,
        valueUnit: GraphValueUnit.none,
        defaultValue: const <int>[0, 0, 0],
      ),
      _valueInputNode(
        id: 'input_integer4_node',
        label: 'Input Integer4',
        description: 'Provides an ivec4 graph input for material parameters.',
        icon: Icons.dashboard_customize_outlined,
        accentColor: _color('#FFB053'),
        valueType: GraphValueType.integer4,
        valueUnit: GraphValueUnit.none,
        defaultValue: const <int>[0, 0, 0, 0],
      ),
      _valueInputNode(
        id: 'input_float_node',
        label: 'Input Float',
        description: 'Provides a float graph input for material parameters.',
        icon: Icons.tune_outlined,
        accentColor: _color('#6AD6FF'),
        valueType: GraphValueType.float,
        valueUnit: GraphValueUnit.none,
        defaultValue: 0.0,
      ),
      _valueInputNode(
        id: 'input_float2_node',
        label: 'Input Float2',
        description: 'Provides a vec2 graph input for material parameters.',
        icon: Icons.open_with_outlined,
        accentColor: _color('#6AD6FF'),
        valueType: GraphValueType.float2,
        valueUnit: GraphValueUnit.none,
        defaultValue: vmath.Vector2.zero(),
      ),
      _valueInputNode(
        id: 'input_float3_node',
        label: 'Input Float3',
        description: 'Provides a vec3 graph input for material parameters.',
        icon: Icons.deblur_outlined,
        accentColor: _color('#6AD6FF'),
        valueType: GraphValueType.float3,
        valueUnit: GraphValueUnit.none,
        defaultValue: vmath.Vector3.zero(),
      ),
      _valueInputNode(
        id: 'input_color_node',
        label: 'Input Color',
        description: 'Provides a color graph input for material parameters.',
        icon: Icons.palette_outlined,
        accentColor: _color('#3DD6B0'),
        valueType: GraphValueType.float4,
        valueUnit: GraphValueUnit.color,
        defaultValue: _white(),
        defaultResourceKinds: const [
          GraphResourceKind.image,
          GraphResourceKind.svg,
        ],
      ),
      _valueInputNode(
        id: 'input_boolean_node',
        label: 'Input Boolean',
        description: 'Provides a boolean graph input for material parameters.',
        icon: Icons.toggle_on_outlined,
        accentColor: _color('#FFB053'),
        valueType: GraphValueType.boolean,
        valueUnit: GraphValueUnit.none,
        defaultValue: false,
      ),
      _valueInputNode(
        id: 'input_matrix3_node',
        label: 'Input Matrix3',
        description: 'Provides a mat3 graph input for material parameters.',
        icon: Icons.grid_3x3_outlined,
        accentColor: _color('#A78BFA'),
        valueType: GraphValueType.float3x3,
        valueUnit: GraphValueUnit.none,
        defaultValue: _identityMatrix3(),
      ),
      _valueInputNode(
        id: 'input_string_node',
        label: 'Input String',
        description: 'Provides a string graph input for material parameters.',
        icon: Icons.short_text_outlined,
        accentColor: _color('#FF9A62'),
        valueType: GraphValueType.stringValue,
        valueUnit: GraphValueUnit.none,
        defaultValue: '',
      ),
      _valueInputNode(
        id: 'input_gradient_node',
        label: 'Input Gradient',
        description: 'Provides a gradient graph input for material parameters.',
        icon: Icons.gradient_outlined,
        accentColor: _color('#FF78B9'),
        valueType: GraphValueType.gradient,
        valueUnit: GraphValueUnit.none,
        defaultValue: _defaultGradient(),
      ),
      _valueInputNode(
        id: 'input_curve_node',
        label: 'Input Curve',
        description:
            'Provides a color-curve graph input for material parameters.',
        icon: Icons.timeline_outlined,
        accentColor: _color('#FF7D7D'),
        valueType: GraphValueType.colorBezierCurve,
        valueUnit: GraphValueUnit.none,
        defaultValue: GraphColorCurveData.identity(),
      ),
      _valueInputNode(
        id: 'input_text_node',
        label: 'Input Text',
        description: 'Provides a text graph input for material parameters.',
        icon: Icons.text_fields_outlined,
        accentColor: _color('#FFB4A2'),
        valueType: GraphValueType.textBlock,
        valueUnit: GraphValueUnit.none,
        defaultValue: GraphTextData.defaults(),
      ),
    ];
  }

  String? inputDefinitionIdForProperty(GraphPropertyDefinition definition) {
    return switch (definition.valueType) {
      GraphValueType.integer => 'input_integer_node',
      GraphValueType.integer2 => 'input_integer2_node',
      GraphValueType.integer3 => 'input_integer3_node',
      GraphValueType.integer4 => 'input_integer4_node',
      GraphValueType.float => 'input_float_node',
      GraphValueType.float2 => 'input_float2_node',
      GraphValueType.float3 => 'input_float3_node',
      GraphValueType.float4
          when definition.socketTransport == GraphSocketTransport.texture ||
              definition.valueUnit == GraphValueUnit.color =>
        'input_color_node',
      GraphValueType.boolean => 'input_boolean_node',
      GraphValueType.float3x3 => 'input_matrix3_node',
      GraphValueType.stringValue => 'input_string_node',
      GraphValueType.gradient => 'input_gradient_node',
      GraphValueType.colorBezierCurve => 'input_curve_node',
      GraphValueType.textBlock => 'input_text_node',
      _ => null,
    };
  }

  GraphValueData defaultValueForProperty(GraphPropertyDefinition definition) {
    return _wrapDefaultValue(definition);
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
      case GraphValueType.float3x3:
        return GraphValueData.float3x3(asFloat3x3(definition.defaultValue));
      case GraphValueType.stringValue:
        return GraphValueData.stringValue(definition.defaultValue as String);
      case GraphValueType.workspaceResource:
        return GraphValueData.workspaceResource(
          asResourceId(definition.defaultValue),
        );
      case GraphValueType.boolean:
        return GraphValueData.boolean(definition.defaultValue as bool);
      case GraphValueType.enumChoice:
        return GraphValueData.enumChoice(definition.defaultValue as int);
      case GraphValueType.gradient:
        return GraphValueData.gradient(asGradient(definition.defaultValue));
      case GraphValueType.colorBezierCurve:
        return GraphValueData.colorCurve(asColorCurve(definition.defaultValue));
      case GraphValueType.textBlock:
        return GraphValueData.textBlock(asTextData(definition.defaultValue));
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

  static GraphGradientData _defaultGradient() => GraphGradientData.identity();

  static List<double> _identityMatrix3() => const <double>[
    1,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
  ];

  static GraphPropertyDefinition _socketColorInput(String key, String label) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.float4,
      valueUnit: GraphValueUnit.color,
      defaultValue: _white(),
      socketTransport: GraphSocketTransport.texture,
    );
  }

  static GraphPropertyDefinition _socketGradientInput(
    String key,
    String label,
  ) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description:
          'Editable gradient fallback when no LUT texture is connected.',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.gradient,
      valueUnit: GraphValueUnit.none,
      defaultValue: _defaultGradient(),
      socketTransport: GraphSocketTransport.texture,
    );
  }

  static GraphPropertyDefinition _outputColorProperty() {
    return GraphPropertyDefinition(
      key: '_output',
      label: 'Output',
      description: 'Empty desc',
      propertyType: GraphPropertyType.output,
      socket: true,
      valueType: GraphValueType.float4,
      valueUnit: GraphValueUnit.color,
      defaultValue: _black(),
      socketTransport: GraphSocketTransport.texture,
    );
  }

  static MaterialNodeDefinition _decorateDefinition(
    MaterialNodeDefinition definition,
  ) {
    return MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: definition.schema.id,
        label: definition.schema.label,
        description: definition.schema.description,
        properties: _withBaseOutputSizeProperties(definition.schema.properties),
      ),
      icon: definition.icon,
      accentColor: definition.accentColor,
      runtime: definition.runtime,
      kind: definition.kind,
      primaryInputPropertyKey: definition.primaryInputPropertyKey,
      inputValuePropertyKey: definition.inputValuePropertyKey,
      inputResourcePropertyKey: definition.inputResourcePropertyKey,
    );
  }

  static List<GraphPropertyDefinition> _withBaseOutputSizeProperties(
    List<GraphPropertyDefinition> properties,
  ) {
    final outputIndex = properties.indexWhere(
      (property) => property.propertyType == GraphPropertyType.output,
    );
    if (outputIndex == -1 ||
        properties.any(
          (property) => property.key == materialNodeOutputSizeModeKey,
        )) {
      return properties;
    }
    return <GraphPropertyDefinition>[
      _outputSizeModeProperty(),
      _outputSizeValueProperty(),
      ...properties.take(outputIndex),
      ...properties.skip(outputIndex),
    ];
  }

  static GraphPropertyDefinition _outputSizeModeProperty() {
    return GraphPropertyDefinition(
      key: materialNodeOutputSizeModeKey,
      label: 'Output Size Mode',
      description:
          'Controls whether this node uses its own size, the primary input, or the graph size.',
      propertyType: GraphPropertyType.input,
      socket: false,
      valueType: GraphValueType.enumChoice,
      valueUnit: GraphValueUnit.none,
      defaultValue: materialOutputSizeModeEnumValue(
        const MaterialOutputSizeSettings.nodeDefault().mode,
      ),
      enumOptions: materialOutputSizeModeOptions,
    );
  }

  static GraphPropertyDefinition _outputSizeValueProperty() {
    return GraphPropertyDefinition(
      key: materialNodeOutputSizeValueKey,
      label: 'Output Size',
      description:
          'Absolute uses log2 size. Relative modes use signed power-of-two offsets.',
      propertyType: GraphPropertyType.input,
      socket: false,
      valueType: GraphValueType.integer2,
      valueUnit: GraphValueUnit.power2,
      defaultValue: const <int>[0, 0],
      min: materialOutputSizeRelativeMinDelta,
      max: materialOutputSizeRelativeMaxDelta,
    );
  }

  static GraphPropertyDefinition _floatInput(
    String key,
    String label, {
    required double defaultValue,
    GraphValueUnit valueUnit = GraphValueUnit.none,
    double? min,
    double? max,
    double? step,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.float,
      valueUnit: valueUnit,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _float2Input(
    String key,
    String label, {
    required vmath.Vector2 defaultValue,
    GraphValueUnit valueUnit = GraphValueUnit.none,
    double? min,
    double? max,
    double? step,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.float2,
      valueUnit: valueUnit,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _float3Input(
    String key,
    String label, {
    required vmath.Vector3 defaultValue,
    GraphValueUnit valueUnit = GraphValueUnit.none,
    double? min,
    double? max,
    double? step,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.float3,
      valueUnit: valueUnit,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _float4Input(
    String key,
    String label, {
    required vmath.Vector4 defaultValue,
    GraphValueUnit valueUnit = GraphValueUnit.none,
    double? min,
    double? max,
    double? step,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.float4,
      valueUnit: valueUnit,
      defaultValue: defaultValue,
      min: min,
      max: max,
      step: step,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _float3x3Input(
    String key,
    String label, {
    required List<double> defaultValue,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: false,
      valueType: GraphValueType.float3x3,
      valueUnit: GraphValueUnit.none,
      defaultValue: defaultValue,
    );
  }

  static GraphPropertyDefinition _boolInput(
    String key,
    String label, {
    required bool defaultValue,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.boolean,
      valueUnit: GraphValueUnit.none,
      defaultValue: defaultValue,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _enumInput(
    String key,
    String label, {
    required int defaultValue,
    required List<EnumChoiceOption> options,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.input,
      socket: true,
      valueType: GraphValueType.enumChoice,
      valueUnit: GraphValueUnit.none,
      defaultValue: defaultValue,
      enumOptions: options,
      socketTransport: GraphSocketTransport.value,
    );
  }

  static GraphPropertyDefinition _curveDescriptorInput(
    String key,
    String label, {
    required String bindingKey,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Editable luminance and RGBA bezier response curves.',
      propertyType: GraphPropertyType.descriptor,
      socket: false,
      valueType: GraphValueType.colorBezierCurve,
      valueUnit: GraphValueUnit.none,
      defaultValue: GraphColorCurveData.identity(),
      runtimeTextureBindingKey: bindingKey,
    );
  }

  static GraphPropertyDefinition _resourceDescriptorInput(
    String key,
    String label, {
    required String bindingKey,
    required List<GraphResourceKind> resourceKinds,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Select a workspace asset to feed this node.',
      propertyType: GraphPropertyType.descriptor,
      socket: false,
      valueType: GraphValueType.workspaceResource,
      valueUnit: GraphValueUnit.path,
      defaultValue: '',
      runtimeTextureBindingKey: bindingKey,
      resourceKinds: resourceKinds,
    );
  }

  static GraphPropertyDefinition _textDescriptorInput(
    String key,
    String label, {
    required String bindingKey,
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Editable text, font, and colors rendered into a texture.',
      propertyType: GraphPropertyType.descriptor,
      socket: false,
      valueType: GraphValueType.textBlock,
      valueUnit: GraphValueUnit.none,
      defaultValue: GraphTextData.defaults(),
      runtimeTextureBindingKey: bindingKey,
    );
  }

  static MaterialNodeDefinition _valueInputNode({
    required String id,
    required String label,
    required String description,
    required IconData icon,
    required vmath.Vector4 accentColor,
    required GraphValueType valueType,
    required GraphValueUnit valueUnit,
    required Object defaultValue,
    List<GraphResourceKind> defaultResourceKinds = const <GraphResourceKind>[],
    List<GraphResourceKind> resourceKinds = const <GraphResourceKind>[],
    List<EnumChoiceOption> enumOptions = const <EnumChoiceOption>[],
  }) {
    return MaterialNodeDefinition(
      schema: GraphNodeSchema(
        id: id,
        label: label,
        description: description,
        properties: [
          GraphPropertyDefinition(
            key: 'value',
            label: 'Default',
            description: 'Fallback value used when the graph input is unbound.',
            propertyType: GraphPropertyType.input,
            socket: false,
            valueType: valueType,
            valueUnit: valueUnit,
            defaultValue: defaultValue,
            isEditable: true,
            enumOptions: enumOptions,
            resourceKinds: resourceKinds,
          ),
          if (defaultResourceKinds.isNotEmpty)
            _resourceDescriptorInput(
              'resource',
              'Default Resource',
              bindingKey: 'MainTex',
              resourceKinds: defaultResourceKinds,
            ),
          _outputSocket(
            key: '_output',
            label: 'Output',
            valueType: valueType,
            valueUnit: valueUnit,
            socketTransport: _inputSocketTransportForValueType(
              valueType: valueType,
              valueUnit: valueUnit,
            ),
            enumOptions: enumOptions,
            resourceKinds: resourceKinds,
          ),
        ],
      ),
      icon: icon,
      accentColor: accentColor,
      runtime: const MaterialNodeRuntimeDefinition.fragment(
        shaderAssetId: 'material/image-basic.frag',
      ),
      kind: MaterialNodeKind.input,
      inputValuePropertyKey: 'value',
      inputResourcePropertyKey: defaultResourceKinds.isEmpty
          ? null
          : 'resource',
    );
  }

  static GraphPropertyDefinition _outputSocket({
    required String key,
    required String label,
    required GraphValueType valueType,
    GraphValueUnit valueUnit = GraphValueUnit.none,
    GraphSocketTransport socketTransport = GraphSocketTransport.value,
    List<EnumChoiceOption> enumOptions = const <EnumChoiceOption>[],
    List<GraphResourceKind> resourceKinds = const <GraphResourceKind>[],
  }) {
    return GraphPropertyDefinition(
      key: key,
      label: label,
      description: 'Empty desc',
      propertyType: GraphPropertyType.output,
      socket: true,
      valueType: valueType,
      valueUnit: valueUnit,
      defaultValue: _defaultOutputValueForType(valueType, valueUnit),
      enumOptions: enumOptions,
      resourceKinds: resourceKinds,
      socketTransport: socketTransport,
    );
  }

  static GraphSocketTransport _inputSocketTransportForValueType({
    required GraphValueType valueType,
    required GraphValueUnit valueUnit,
  }) {
    if (valueUnit == GraphValueUnit.color) {
      return GraphSocketTransport.texture;
    }

    return switch (valueType) {
      GraphValueType.workspaceResource ||
      GraphValueType.gradient ||
      GraphValueType.colorBezierCurve ||
      GraphValueType.textBlock => GraphSocketTransport.texture,
      _ => GraphSocketTransport.value,
    };
  }

  static Object _defaultOutputValueForType(
    GraphValueType valueType,
    GraphValueUnit valueUnit,
  ) {
    if (valueUnit == GraphValueUnit.color &&
        valueType == GraphValueType.float4) {
      return _black();
    }
    return _defaultValueForType(valueType);
  }

  static Object _defaultValueForType(GraphValueType valueType) {
    switch (valueType) {
      case GraphValueType.integer:
        return 0;
      case GraphValueType.integer2:
        return const <int>[0, 0];
      case GraphValueType.integer3:
        return const <int>[0, 0, 0];
      case GraphValueType.integer4:
        return const <int>[0, 0, 0, 0];
      case GraphValueType.float:
        return 0.0;
      case GraphValueType.float2:
        return vmath.Vector2.zero();
      case GraphValueType.float3:
        return vmath.Vector3.zero();
      case GraphValueType.float4:
        return vmath.Vector4.zero();
      case GraphValueType.float3x3:
        return _identityMatrix3();
      case GraphValueType.stringValue:
        return '';
      case GraphValueType.workspaceResource:
        return '';
      case GraphValueType.boolean:
        return false;
      case GraphValueType.enumChoice:
        return 0;
      case GraphValueType.gradient:
        return _defaultGradient();
      case GraphValueType.colorBezierCurve:
        return GraphColorCurveData.identity();
      case GraphValueType.textBlock:
        return GraphTextData.defaults();
    }
  }
}
