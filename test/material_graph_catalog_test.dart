import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/material_graph/material_graph_catalog.dart';
import 'package:eyecandy/shared/ids/id_factory.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
