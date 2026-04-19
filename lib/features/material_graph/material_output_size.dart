import 'dart:math' as math;

import '../graph/models/graph_schema.dart';

enum MaterialOutputSizeMode { absolute, relativeToInput, relativeToParent }

const String materialNodeOutputSizeModeKey = 'outputSizeMode';
const String materialNodeOutputSizeValueKey = 'outputSizeValue';

const int materialOutputSizeMinLog2 = 4;
const int materialOutputSizeMaxLog2 = 11;
const int materialOutputSizeRelativeMinDelta = -12;
const int materialOutputSizeRelativeMaxDelta = 12;

const List<EnumChoiceOption> materialOutputSizeModeOptions = [
  EnumChoiceOption(id: 'absolute', label: 'Absolute', value: 0),
  EnumChoiceOption(
    id: 'relative_to_input',
    label: 'Relative to input',
    value: 1,
  ),
  EnumChoiceOption(
    id: 'relative_to_parent',
    label: 'Relative to parent',
    value: 2,
  ),
];

class MaterialOutputSizeValue {
  const MaterialOutputSizeValue({
    required this.widthLog2,
    required this.heightLog2,
  });

  const MaterialOutputSizeValue.square(int log2)
    : widthLog2 = log2,
      heightLog2 = log2;

  const MaterialOutputSizeValue.parentDefault() : widthLog2 = 9, heightLog2 = 9;

  const MaterialOutputSizeValue.zero() : widthLog2 = 0, heightLog2 = 0;

  final int widthLog2;
  final int heightLog2;

  List<int> get asInteger2 => <int>[widthLog2, heightLog2];

  MaterialOutputSizeValue copyWith({int? widthLog2, int? heightLog2}) {
    return MaterialOutputSizeValue(
      widthLog2: widthLog2 ?? this.widthLog2,
      heightLog2: heightLog2 ?? this.heightLog2,
    );
  }

  MaterialOutputSizeValue clampAbsolute({
    int min = materialOutputSizeMinLog2,
    int max = materialOutputSizeMaxLog2,
  }) {
    return MaterialOutputSizeValue(
      widthLog2: widthLog2.clamp(min, max),
      heightLog2: heightLog2.clamp(min, max),
    );
  }

  MaterialOutputSizeValue clampRelative({
    int min = materialOutputSizeRelativeMinDelta,
    int max = materialOutputSizeRelativeMaxDelta,
  }) {
    return MaterialOutputSizeValue(
      widthLog2: widthLog2.clamp(min, max),
      heightLog2: heightLog2.clamp(min, max),
    );
  }

  MaterialOutputSizeValue add(MaterialOutputSizeValue other) {
    return MaterialOutputSizeValue(
      widthLog2: widthLog2 + other.widthLog2,
      heightLog2: heightLog2 + other.heightLog2,
    );
  }

  MaterialOutputSizeValue subtract(MaterialOutputSizeValue other) {
    return MaterialOutputSizeValue(
      widthLog2: widthLog2 - other.widthLog2,
      heightLog2: heightLog2 - other.heightLog2,
    );
  }

  int get width => _log2ToPixels(widthLog2);

  int get height => _log2ToPixels(heightLog2);

  int pixelsForAxis(bool isWidth) {
    return materialOutputSizePixelsForLog2(isWidth ? widthLog2 : heightLog2);
  }

  static MaterialOutputSizeValue fromInteger2(List<int> value) {
    final normalized = value.length >= 2 ? value : const <int>[0, 0];
    return MaterialOutputSizeValue(
      widthLog2: normalized.firstOrNull ?? 0,
      heightLog2: normalized.elementAtOrNull(1) ?? normalized.firstOrNull ?? 0,
    );
  }

  factory MaterialOutputSizeValue.fromJson(Map<String, dynamic> json) {
    return MaterialOutputSizeValue(
      widthLog2: (json['widthLog2'] as num?)?.toInt() ?? 0,
      heightLog2: (json['heightLog2'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'widthLog2': widthLog2,
    'heightLog2': heightLog2,
  };

  static int _log2ToPixels(int log2) {
    return materialOutputSizePixelsForLog2(log2);
  }
}

class MaterialOutputSizeSettings {
  const MaterialOutputSizeSettings({
    this.mode = MaterialOutputSizeMode.relativeToParent,
    this.value = const MaterialOutputSizeValue.zero(),
  });

  const MaterialOutputSizeSettings.nodeDefault()
    : mode = MaterialOutputSizeMode.relativeToParent,
      value = const MaterialOutputSizeValue.zero();

  const MaterialOutputSizeSettings.nodeFallback()
    : mode = MaterialOutputSizeMode.relativeToInput,
      value = const MaterialOutputSizeValue.zero();

  final MaterialOutputSizeMode mode;
  final MaterialOutputSizeValue value;

  MaterialOutputSizeSettings copyWith({
    MaterialOutputSizeMode? mode,
    MaterialOutputSizeValue? value,
  }) {
    return MaterialOutputSizeSettings(
      mode: mode ?? this.mode,
      value: value ?? this.value,
    );
  }

  bool get usesAbsolutePixels => mode == MaterialOutputSizeMode.absolute;

  MaterialOutputSizeValue normalizeValue(MaterialOutputSizeValue rawValue) {
    return usesAbsolutePixels
        ? rawValue.clampAbsolute()
        : rawValue.clampRelative();
  }

  factory MaterialOutputSizeSettings.fromJson(Map<String, dynamic> json) {
    return MaterialOutputSizeSettings(
      mode: MaterialOutputSizeMode.values.byName(
        json['mode'] as String? ?? MaterialOutputSizeMode.relativeToParent.name,
      ),
      value: json['value'] is Map<String, dynamic>
          ? MaterialOutputSizeValue.fromJson(
              json['value'] as Map<String, dynamic>,
            )
          : const MaterialOutputSizeValue.zero(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.name,
    'value': value.toJson(),
  };
}

String materialOutputSizeModeLabel(MaterialOutputSizeMode mode) {
  return switch (mode) {
    MaterialOutputSizeMode.absolute => 'Absolute',
    MaterialOutputSizeMode.relativeToInput => 'Relative to input',
    MaterialOutputSizeMode.relativeToParent => 'Relative to parent',
  };
}

MaterialOutputSizeMode materialOutputSizeModeFromEnumValue(int value) {
  return switch (value) {
    0 => MaterialOutputSizeMode.absolute,
    1 => MaterialOutputSizeMode.relativeToInput,
    _ => MaterialOutputSizeMode.relativeToParent,
  };
}

int materialOutputSizeModeEnumValue(MaterialOutputSizeMode mode) {
  return switch (mode) {
    MaterialOutputSizeMode.absolute => 0,
    MaterialOutputSizeMode.relativeToInput => 1,
    MaterialOutputSizeMode.relativeToParent => 2,
  };
}

int materialOutputSizePixelsForLog2(int log2) {
  final clamped = log2.clamp(
    materialOutputSizeMinLog2,
    materialOutputSizeMaxLog2,
  );
  return math.pow(2, clamped).toInt();
}

MaterialOutputSizeSettings materialOutputSizeSettingsFromStorage({
  int? modeValue,
  List<int>? value,
  MaterialOutputSizeSettings fallback =
      const MaterialOutputSizeSettings.nodeFallback(),
}) {
  return MaterialOutputSizeSettings(
    mode: materialOutputSizeModeFromEnumValue(
      modeValue ?? materialOutputSizeModeEnumValue(fallback.mode),
    ),
    value: MaterialOutputSizeValue.fromInteger2(
      value ?? fallback.value.asInteger2,
    ),
  );
}

extension on List<int> {
  int? get firstOrNull => isEmpty ? null : first;

  int? elementAtOrNull(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return this[index];
  }
}
