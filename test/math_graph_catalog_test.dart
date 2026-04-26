import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/math_graph/math_graph_catalog.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('catalog exposes typed math nodes with expected defaults', () {
    final catalog = MathGraphCatalog(IdFactory());

    final floatConstant = catalog.definitionById('float_constant_node');
    final floatInput = catalog.definitionById('get_float1_node');
    final breakFloat3 = catalog.definitionById('break_float3_node');
    final sampler = catalog.definitionById('sample_color_node');
    final output = catalog.definitionById('output_float4_node');
    final setFloat = catalog.definitionById('set_float_node');

    expect(floatConstant.properties.map((property) => property.key), [
      'value',
      '_output',
    ]);
    expect(floatConstant.propertyDefinition('value').defaultValue, 0.0);
    expect(floatConstant.propertyDefinition('_output').valueType, GraphValueType.float);

    expect(floatInput.properties.map((property) => property.key), [
      'identifier',
      'defaultValue',
      'unit',
      'hasMin',
      'min',
      'hasMax',
      'max',
      'step',
      '_output',
    ]);
    expect(floatInput.propertyDefinition('defaultValue').defaultValue, 0.0);
    expect(floatInput.propertyDefinition('step').defaultValue, 0.01);

    expect(breakFloat3.properties.map((property) => property.key), [
      'input',
      'x',
      'y',
      'z',
    ]);
    expect(breakFloat3.propertyDefinition('x').valueType, GraphValueType.float);

    expect(sampler.properties.map((property) => property.key), [
      'sourceIndex',
      'uv',
      '_output',
    ]);
    expect(sampler.propertyDefinition('sourceIndex').defaultValue, 0);
    expect(sampler.propertyDefinition('uv').valueType, GraphValueType.float2);
    expect(sampler.propertyDefinition('_output').valueType, GraphValueType.float4);

    expect(output.isGraphOutput, isTrue);
    expect(output.compileMetadata.outputPropertyKey, 'value');
    expect(output.propertyDefinition('value').socketDirection, GraphSocketDirection.input);

    expect(setFloat.propertyDefinition('identifier').valueType, GraphValueType.stringValue);
    expect(setFloat.propertyDefinition('value').valueType, GraphValueType.float);
  });

  test('instantiateNode wraps shared default values into GraphValueData', () {
    final catalog = MathGraphCatalog(IdFactory());
    final node = catalog.instantiateNode(
      definitionId: 'float4_constant_node',
      position: Vector2(10, 20),
    );

    final value = node.propertyByDefinitionKey('value')!.value;
    final output = node.propertyByDefinitionKey('_output')!.value;

    expect(node.position.x, 10);
    expect(node.position.y, 20);
    expect(value.valueType, GraphValueType.float4);
    expect(value.asFloat4().storage, [0.0, 0.0, 0.0, 0.0]);
    expect(output.valueType, GraphValueType.float4);
  });
}
