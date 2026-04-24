import 'package:collection/collection.dart';

import '../graph/models/graph_schema.dart';

const ListEquality<EnumChoiceOption> _enumOptionListEquality =
    ListEquality<EnumChoiceOption>(_EnumChoiceOptionEquality());
const SetEquality<GraphResourceKind> _resourceKindSetEquality =
    SetEquality<GraphResourceKind>();

bool materialSocketDefinitionsCompatible({
  required GraphPropertyDefinition fromDefinition,
  required GraphPropertyDefinition toDefinition,
}) {
  if (fromDefinition.socketDirection != GraphSocketDirection.output ||
      toDefinition.socketDirection != GraphSocketDirection.input) {
    return false;
  }
  if (fromDefinition.valueType != toDefinition.valueType) {
    return false;
  }
  if (!_enumOptionsCompatible(fromDefinition, toDefinition)) {
    return false;
  }
  if (!_resourceKindsCompatible(fromDefinition, toDefinition)) {
    return false;
  }
  return true;
}

bool _enumOptionsCompatible(
  GraphPropertyDefinition fromDefinition,
  GraphPropertyDefinition toDefinition,
) {
  if (fromDefinition.valueType != GraphValueType.enumChoice) {
    return true;
  }

  return _enumOptionListEquality.equals(
    fromDefinition.enumOptions,
    toDefinition.enumOptions,
  );
}

bool _resourceKindsCompatible(
  GraphPropertyDefinition fromDefinition,
  GraphPropertyDefinition toDefinition,
) {
  if (fromDefinition.resourceKinds.isEmpty || toDefinition.resourceKinds.isEmpty) {
    return true;
  }

  return _resourceKindSetEquality.equals(
    fromDefinition.resourceKinds.toSet(),
    toDefinition.resourceKinds.toSet(),
  );
}

class _EnumChoiceOptionEquality implements Equality<EnumChoiceOption> {
  const _EnumChoiceOptionEquality();

  @override
  bool equals(EnumChoiceOption e1, EnumChoiceOption e2) {
    return e1.id == e2.id && e1.label == e2.label && e1.value == e2.value;
  }

  @override
  int hash(EnumChoiceOption e) => Object.hash(e.id, e.label, e.value);

  @override
  bool isValidKey(Object? o) => o is EnumChoiceOption;
}
