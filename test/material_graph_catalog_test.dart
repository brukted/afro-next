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

    expect(
      solidColor.properties.map((property) => property.key),
      ['color', '_output'],
    );
    expect(
      mix.properties.map((property) => property.key),
      ['Foreground', 'Background', 'Mask', 'blendMode', 'alphaMode', 'alpha', '_output'],
    );
    expect(
      channelSelect.properties.map((property) => property.key),
      [
        'input1',
        'input2',
        'channel_red',
        'channel_green',
        'channel_blue',
        'channel_alpha',
        '_output',
      ],
    );
    expect(
      circle.properties.map((property) => property.key),
      ['radius', 'outline', 'width', 'height', '_output'],
    );

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
    expect(mix.propertyDefinition('_output').propertyType, GraphPropertyType.output);
    expect(mix.propertyDefinition('Mask').valueUnit, GraphValueUnit.color);
  });

  test('catalog matches Afro material defaults', () {
    final catalog = MaterialGraphCatalog(IdFactory());
    final solidColor = catalog.definitionById('solid_color_node');
    final mix = catalog.definitionById('mix_node');
    final channelSelect = catalog.definitionById('channel_select_node');
    final circle = catalog.definitionById('circle_node');

    expect(_vector4Values(solidColor.propertyDefinition('color').defaultValue as Vector4), [
      1.0,
      1.0,
      1.0,
      1.0,
    ]);
    expect(_vector4Values(mix.propertyDefinition('Foreground').defaultValue as Vector4), [
      1.0,
      1.0,
      1.0,
      1.0,
    ]);
    expect(_vector4Values(channelSelect.propertyDefinition('input1').defaultValue as Vector4), [
      1.0,
      1.0,
      1.0,
      1.0,
    ]);
    expect(circle.propertyDefinition('width').defaultValue, 0.1);
    expect(circle.propertyDefinition('height').defaultValue, 0.1);
  });
}

List<double> _vector4Values(Vector4 value) => [value.x, value.y, value.z, value.w];
