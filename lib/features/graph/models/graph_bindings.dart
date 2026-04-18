import 'graph_models.dart';
import 'graph_schema.dart';

class GraphPropertyBinding {
  const GraphPropertyBinding({
    required this.property,
    required this.definition,
  });

  final GraphNodePropertyData property;
  final GraphPropertyDefinition definition;

  String get id => property.id;

  String get label => definition.label;

  GraphValueData get valueData => property.value;

  Object get value => property.value.unwrap();

  bool get isEditable =>
      !definition.isSocket ||
      definition.propertyType == GraphPropertyType.input ||
      definition.isEditable;
}
