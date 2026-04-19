import 'dart:typed_data';

import '../../features/graph/models/graph_models.dart';
import '../../features/material_graph/material_node_definition.dart';
import '../../features/material_graph/runtime/material_execution_ir.dart';

typedef MaterialUniformPackingFunction =
    Uint8List Function(
      MaterialCompiledNodePass pass,
      MaterialPreviewPackingContext context,
    );

class MaterialPreviewPackingContext {
  const MaterialPreviewPackingContext({required this.previewExtent});

  final int previewExtent;
}

class MaterialNodePreviewSupport {
  const MaterialNodePreviewSupport({
    required this.executionKind,
    required this.packUniforms,
  });

  final MaterialNodeExecutionKind executionKind;
  final MaterialUniformPackingFunction packUniforms;
}

class MaterialNodePreviewSupportRegistry {
  const MaterialNodePreviewSupportRegistry._();

  static final Map<String, MaterialNodePreviewSupport> _supportByDefinitionId =
      <String, MaterialNodePreviewSupport>{
        'solid_color_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packSolidColorUniforms,
        ),
        'circle_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packCircleUniforms,
        ),
        'channel_select_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packChannelSelectUniforms,
        ),
        'mix_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packMixUniforms,
        ),
        'image_basic_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'image_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'svg_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'text_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'gamma_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packGammaUniforms,
        ),
        'levels_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packLevelsUniforms,
        ),
        'grayscaleconv_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packGrayscaleUniforms,
        ),
        'hsl_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packHslUniforms,
        ),
        'invert_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packInvertUniforms,
        ),
        'sharpen_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packSharpenUniforms,
        ),
        'blur_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packBlurUniforms,
        ),
        'motionblur_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packMotionBlurUniforms,
        ),
        'warp_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packWarpUniforms,
        ),
        'warpdirectional_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packWarpDirectionalUniforms,
        ),
        'normals_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNormalsUniforms,
        ),
        'emboss_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packEmbossUniforms,
        ),
        'fx_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packFxUniforms,
        ),
        'gradientmap_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packGradientMapUniforms,
        ),
        'curve_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'occlusion_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'transform_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packTransformUniforms,
        ),
        'bloom_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
        'uv_node': const MaterialNodePreviewSupport(
          executionKind: MaterialNodeExecutionKind.fragment,
          packUniforms: _packNoUniforms,
        ),
      };

  static MaterialNodePreviewSupport? lookup(MaterialCompiledNodePass pass) {
    final support = _supportByDefinitionId[pass.definitionId];
    if (support == null) {
      return null;
    }
    if (pass.shaderAssetId == null ||
        pass.executionKind != support.executionKind) {
      return null;
    }
    return support;
  }

  static Uint8List packUniforms(
    MaterialCompiledNodePass pass, {
    required MaterialPreviewPackingContext context,
  }) {
    final support = lookup(pass);
    if (support == null) {
      throw UnsupportedError(
        'No Vulkan preview support registered for ${pass.definitionId}.',
      );
    }
    return support.packUniforms(pass, context);
  }

  static Uint8List _packNoUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(0, 0, 0, 0);
  }

  static Uint8List _packSolidColorUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final color = _parameter(pass, 'color').asFloat4();
    return _floatBlock4(color.x, color.y, color.z, color.w);
  }

  static Uint8List _packCircleUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'radius').floatValue ?? 0.5,
      _parameter(pass, 'outline').floatValue ?? 0,
      _parameter(pass, 'width').floatValue ?? 1,
      _parameter(pass, 'height').floatValue ?? 1,
    );
  }

  static Uint8List _packChannelSelectUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _intBlock4(
      _parameter(pass, 'channel_red').enumValue ?? 0,
      _parameter(pass, 'channel_green').enumValue ?? 1,
      _parameter(pass, 'channel_blue').enumValue ?? 2,
      _parameter(pass, 'channel_alpha').enumValue ?? 3,
    );
  }

  static Uint8List _packMixUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final data = ByteData(32)
      ..setInt32(0, _parameter(pass, 'blendMode').enumValue ?? 1, Endian.little)
      ..setInt32(4, _parameter(pass, 'alphaMode').enumValue ?? 0, Endian.little)
      ..setInt32(8, 0, Endian.little)
      ..setInt32(12, 0, Endian.little)
      ..setFloat32(16, _parameter(pass, 'alpha').floatValue ?? 1, Endian.little)
      ..setFloat32(20, 0, Endian.little)
      ..setFloat32(24, 0, Endian.little)
      ..setFloat32(28, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _packGammaUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(_parameter(pass, 'gamma').floatValue ?? 2.2, 0, 0, 0);
  }

  static Uint8List _packGrayscaleUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final weight = _parameter(pass, 'weight').asFloat4();
    return _floatBlock4(weight.x, weight.y, weight.z, weight.w);
  }

  static Uint8List _packLevelsUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final minValues = _parameter(pass, 'minValues').asFloat3();
    final maxValues = _parameter(pass, 'maxValues').asFloat3();
    final midValues = _parameter(pass, 'midValues').asFloat3();
    final value = _parameter(pass, 'value').asFloat2();
    final data = ByteData(64)
      ..setFloat32(0, minValues.x, Endian.little)
      ..setFloat32(4, minValues.y, Endian.little)
      ..setFloat32(8, minValues.z, Endian.little)
      ..setFloat32(12, 0, Endian.little)
      ..setFloat32(16, maxValues.x, Endian.little)
      ..setFloat32(20, maxValues.y, Endian.little)
      ..setFloat32(24, maxValues.z, Endian.little)
      ..setFloat32(28, 0, Endian.little)
      ..setFloat32(32, midValues.x, Endian.little)
      ..setFloat32(36, midValues.y, Endian.little)
      ..setFloat32(40, midValues.z, Endian.little)
      ..setFloat32(44, 0, Endian.little)
      ..setFloat32(48, value.x, Endian.little)
      ..setFloat32(52, value.y, Endian.little)
      ..setFloat32(56, 0, Endian.little)
      ..setFloat32(60, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _packHslUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'hue').floatValue ?? 0,
      _parameter(pass, 'saturation').floatValue ?? 0,
      _parameter(pass, 'lightness').floatValue ?? 0,
      0,
    );
  }

  static Uint8List _packInvertUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _intBlock4(
      _boolAsInt(_parameter(pass, 'invertRed').boolValue ?? true),
      _boolAsInt(_parameter(pass, 'invertGreen').boolValue ?? true),
      _boolAsInt(_parameter(pass, 'invertBlue').boolValue ?? true),
      _boolAsInt(_parameter(pass, 'invertAlpha').boolValue ?? false),
    );
  }

  static Uint8List _packSharpenUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'intensity').floatValue ?? 1,
      0,
      0,
      0,
    );
  }

  static Uint8List _packBlurUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final pixelShape = _parameter(pass, 'pixel_shape').asFloat2();
    return _floatBlock4(
      _parameter(pass, 'intensity').floatValue ?? 8,
      pixelShape.x,
      pixelShape.y,
      0,
    );
  }

  static Uint8List _packMotionBlurUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'tx').floatValue ?? 1,
      _parameter(pass, 'ty').floatValue ?? 0,
      _parameter(pass, 'magnitude').floatValue ?? 8,
      0,
    );
  }

  static Uint8List _packWarpUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'intensity').floatValue ?? 1,
      0,
      0,
      0,
    );
  }

  static Uint8List _packWarpDirectionalUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      _parameter(pass, 'intensity').floatValue ?? 1,
      _parameter(pass, 'angle').floatValue ?? 0,
      0,
      0,
    );
  }

  static Uint8List _packNormalsUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final data = ByteData(32)
      ..setFloat32(0, context.previewExtent.toDouble(), Endian.little)
      ..setFloat32(4, context.previewExtent.toDouble(), Endian.little)
      ..setFloat32(
        8,
        _parameter(pass, 'intensity').floatValue ?? 1,
        Endian.little,
      )
      ..setFloat32(
        12,
        _parameter(pass, 'reduce').floatValue ?? 0.004,
        Endian.little,
      )
      ..setInt32(
        16,
        _boolAsInt(_parameter(pass, 'directx').boolValue ?? false),
        Endian.little,
      )
      ..setInt32(20, 0, Endian.little)
      ..setInt32(24, 0, Endian.little)
      ..setInt32(28, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _packEmbossUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _floatBlock4(
      context.previewExtent.toDouble(),
      context.previewExtent.toDouble(),
      _parameter(pass, 'azimuth').floatValue ?? 0,
      _parameter(pass, 'elevation').floatValue ?? 1,
    );
  }

  static Uint8List _packFxUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _intBlock4(_parameter(pass, 'blendMode').enumValue ?? 0, 0, 0, 0);
  }

  static Uint8List _packGradientMapUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    return _intBlock4(
      _boolAsInt(_parameter(pass, 'useMask').boolValue ?? false),
      _boolAsInt(_parameter(pass, 'horizontal').boolValue ?? true),
      0,
      0,
    );
  }

  static Uint8List _packTransformUniforms(
    MaterialCompiledNodePass pass,
    MaterialPreviewPackingContext context,
  ) {
    final rotation = _parameter(pass, 'rotation').asFloat3x3();
    final scale = _parameter(pass, 'scale').asFloat3x3();
    final translation = _parameter(pass, 'translation').asFloat3();
    final data = ByteData(112);
    _writeMatrix3Columns(data, 0, rotation);
    _writeMatrix3Columns(data, 48, scale);
    data
      ..setFloat32(96, translation.x, Endian.little)
      ..setFloat32(100, translation.y, Endian.little)
      ..setFloat32(104, translation.z, Endian.little)
      ..setFloat32(108, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static GraphValueData _parameter(
    MaterialCompiledNodePass pass,
    String bindingKey,
  ) {
    return pass.parameterBindings
        .firstWhere((binding) => binding.bindingKey == bindingKey)
        .value;
  }

  static Uint8List _floatBlock4(double x, double y, double z, double w) {
    final data = ByteData(16)
      ..setFloat32(0, x, Endian.little)
      ..setFloat32(4, y, Endian.little)
      ..setFloat32(8, z, Endian.little)
      ..setFloat32(12, w, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _intBlock4(int x, int y, int z, int w) {
    final data = ByteData(16)
      ..setInt32(0, x, Endian.little)
      ..setInt32(4, y, Endian.little)
      ..setInt32(8, z, Endian.little)
      ..setInt32(12, w, Endian.little);
    return data.buffer.asUint8List();
  }

  static int _boolAsInt(bool value) => value ? 1 : 0;

  static void _writeMatrix3Columns(
    ByteData data,
    int offset,
    List<double> matrix,
  ) {
    final values = matrix.length >= 9
        ? matrix
        : const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
    final columns = <List<double>>[
      <double>[values[0], values[3], values[6], 0],
      <double>[values[1], values[4], values[7], 0],
      <double>[values[2], values[5], values[8], 0],
    ];
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex += 1) {
      final column = columns[columnIndex];
      final baseOffset = offset + (columnIndex * 16);
      data
        ..setFloat32(baseOffset, column[0], Endian.little)
        ..setFloat32(baseOffset + 4, column[1], Endian.little)
        ..setFloat32(baseOffset + 8, column[2], Endian.little)
        ..setFloat32(baseOffset + 12, column[3], Endian.little);
    }
  }
}
