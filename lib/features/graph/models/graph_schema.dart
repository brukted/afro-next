import 'package:vector_math/vector_math.dart';

enum GraphValueType { scalar, color, enumChoice }

enum GraphSocketDirection { input, output }

class EnumChoiceOption {
  const EnumChoiceOption({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final int value;
}

class GraphPropertyDefinition {
  const GraphPropertyDefinition({
    required this.key,
    required this.label,
    required this.valueType,
    required this.defaultValue,
    this.socketDirection,
    this.min,
    this.max,
    this.enumOptions = const <EnumChoiceOption>[],
  });

  final String key;
  final String label;
  final GraphValueType valueType;
  final Object defaultValue;
  final GraphSocketDirection? socketDirection;
  final double? min;
  final double? max;
  final List<EnumChoiceOption> enumOptions;

  bool get isSocket => socketDirection != null;
}

class GraphNodeSchema {
  const GraphNodeSchema({
    required this.id,
    required this.label,
    required this.description,
    required this.properties,
  });

  final String id;
  final String label;
  final String description;
  final List<GraphPropertyDefinition> properties;

  GraphPropertyDefinition propertyDefinition(String key) {
    return properties.firstWhere((property) => property.key == key);
  }
}

Vector4 asVector4(Object value) => (value as Vector4).clone();

