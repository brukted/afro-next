import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('enum properties use valid default values', () {
    final catalog = MaterialGraphCatalog(IdFactory());

    for (final definition in catalog.definitions) {
      for (final property in definition.properties.where(
        (entry) => entry.valueType == GraphValueType.enumChoice,
      )) {
        final defaultValue = property.defaultValue as int;
        final optionValues = property.enumOptions.map((option) => option.value);

        expect(
          optionValues,
          contains(defaultValue),
          reason:
              'Property ${definition.id}.${property.key} has default $defaultValue '
              'but no matching enum option.',
        );
      }
    }
  });

  test('catalog matches Afro material property keys and enum presets', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final solidColor = catalog.definitionById('solid_color_node');
    final mix = catalog.definitionById('mix_node');
    final channelSelect = catalog.definitionById('channel_select_node');
    final circle = catalog.definitionById('circle_node');

    expect(solidColor.properties.map((property) => property.key), [
      'color',
      '_output',
    ]);
    expect(mix.properties.map((property) => property.key), [
      'Foreground',
      'Background',
      'Mask',
      'blendMode',
      'alphaMode',
      'alpha',
      '_output',
    ]);
    expect(channelSelect.properties.map((property) => property.key), [
      'input1',
      'input2',
      'channel_red',
      'channel_green',
      'channel_blue',
      'channel_alpha',
      '_output',
    ]);
    expect(circle.properties.map((property) => property.key), [
      'radius',
      'outline',
      'width',
      'height',
      '_output',
    ]);

    final blendMode = mix.propertyDefinition('blendMode');
    expect(blendMode.enumOptions.length, 25);
    expect(blendMode.defaultValue, 0);
    expect(blendMode.enumOptions.first.label, 'Add Sub');
    expect(blendMode.enumOptions.last.label, 'Exclusion');

    final alphaMode = mix.propertyDefinition('alphaMode');
    expect(alphaMode.enumOptions.map((option) => option.label), [
      'Background',
      'Foreground',
      'Min',
      'Max',
      'Average',
      'Add',
    ]);

    expect(mix.propertyDefinition('Foreground').isSocket, isTrue);
    expect(mix.propertyDefinition('Mask').isSocket, isTrue);
    expect(
      mix.propertyDefinition('_output').propertyType,
      GraphPropertyType.output,
    );
    expect(mix.propertyDefinition('Mask').valueUnit, GraphValueUnit.color);
  });

  test('catalog matches Afro material defaults', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final solidColor = catalog.definitionById('solid_color_node');
    final mix = catalog.definitionById('mix_node');
    final channelSelect = catalog.definitionById('channel_select_node');
    final circle = catalog.definitionById('circle_node');
    final curveDemo = catalog.definitionById('curve_demo_node');

    expect(
      _vector4Values(
        solidColor.propertyDefinition('color').defaultValue as Vector4,
      ),
      [1.0, 1.0, 1.0, 1.0],
    );
    expect(
      _vector4Values(
        mix.propertyDefinition('Foreground').defaultValue as Vector4,
      ),
      [1.0, 1.0, 1.0, 1.0],
    );
    expect(
      _vector4Values(
        channelSelect.propertyDefinition('input1').defaultValue as Vector4,
      ),
      [1.0, 1.0, 1.0, 1.0],
    );
    expect(circle.propertyDefinition('width').defaultValue, 0.1);
    expect(circle.propertyDefinition('height').defaultValue, 0.1);
    expect(
      curveDemo.propertyDefinition('curve').defaultValue,
      isA<GraphColorCurveData>(),
    );
    expect(
      (curveDemo.propertyDefinition('curve').defaultValue
              as GraphColorCurveData)
          .lum
          .points
          .length,
      2,
    );
  });

  test('starter graph includes the curve demo node', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final graph = catalog.createStarterGraph(name: 'Starter');

    expect(
      graph.nodes.any((node) => node.definitionId == 'curve_demo_node'),
      isTrue,
    );
  });

  test('catalog exposes Afro fullscreen expansion nodes with expected contracts', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final image = catalog.definitionById('image_node');
    final svg = catalog.definitionById('svg_node');
    final text = catalog.definitionById('text_node');
    final levels = catalog.definitionById('levels_node');
    final curve = catalog.definitionById('curve_node');
    final transform = catalog.definitionById('transform_node');
    final gradientMap = catalog.definitionById('gradientmap_node');

    expect(image.runtime.shaderAssetId, 'material/image-basic.frag');
    expect(
      image.propertyDefinition('resource').valueType,
      GraphValueType.workspaceResource,
    );
    expect(
      image.propertyDefinition('resource').resourceKinds,
      [GraphResourceKind.image],
    );
    expect(
      image.propertyDefinition('resource').runtimeTextureBindingKey,
      'MainTex',
    );

    expect(svg.runtime.shaderAssetId, 'material/image-basic.frag');
    expect(
      svg.propertyDefinition('resource').resourceKinds,
      [GraphResourceKind.svg],
    );

    expect(text.runtime.shaderAssetId, 'material/image-basic.frag');
    expect(
      text.propertyDefinition('content').valueType,
      GraphValueType.textBlock,
    );

    expect(levels.runtime.shaderAssetId, 'material/levels.frag');
    expect(levels.properties.map((property) => property.key), [
      'MainTex',
      'minValues',
      'maxValues',
      'midValues',
      'value',
      '_output',
    ]);

    expect(
      curve.propertyDefinition('curve').runtimeTextureBindingKey,
      'CurveLUT',
    );
    expect(
      curve.propertyDefinition('curve').defaultValue,
      isA<GraphColorCurveData>(),
    );

    expect(
      transform.propertyDefinition('rotation').valueType,
      GraphValueType.float3x3,
    );
    expect(
      transform.propertyDefinition('translation').valueType,
      GraphValueType.float3,
    );

    expect(gradientMap.properties.map((property) => property.key), [
      'MainTex',
      'ColorLUT',
      'Mask',
      'useMask',
      'horizontal',
      '_output',
    ]);
    expect(
      gradientMap.propertyDefinition('ColorLUT').valueType,
      GraphValueType.gradient,
    );
  });
}

List<double> _vector4Values(Vector4 value) => [
  value.x,
  value.y,
  value.z,
  value.w,
];
