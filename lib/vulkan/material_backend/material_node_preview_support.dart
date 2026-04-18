import 'dart:typed_data';

import '../../features/graph/models/graph_models.dart';
import '../../features/material_graph/material_node_definition.dart';
import '../../features/material_graph/runtime/material_execution_ir.dart';

typedef MaterialUniformPackingFunction =
    Uint8List Function(MaterialCompiledNodePass pass);

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

  static Uint8List packUniforms(MaterialCompiledNodePass pass) {
    final support = lookup(pass);
    if (support == null) {
      throw UnsupportedError(
        'No Vulkan preview support registered for ${pass.definitionId}.',
      );
    }
    return support.packUniforms(pass);
  }

  static Uint8List _packSolidColorUniforms(MaterialCompiledNodePass pass) {
    final color = _parameter(pass, 'color').asFloat4();
    final data = ByteData(16)
      ..setFloat32(0, color.x, Endian.little)
      ..setFloat32(4, color.y, Endian.little)
      ..setFloat32(8, color.z, Endian.little)
      ..setFloat32(12, color.w, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _packCircleUniforms(MaterialCompiledNodePass pass) {
    final data = ByteData(16)
      ..setFloat32(
        0,
        _parameter(pass, 'radius').floatValue ?? 0.5,
        Endian.little,
      )
      ..setFloat32(
        4,
        _parameter(pass, 'outline').floatValue ?? 0,
        Endian.little,
      )
      ..setFloat32(8, _parameter(pass, 'width').floatValue ?? 1, Endian.little)
      ..setFloat32(
        12,
        _parameter(pass, 'height').floatValue ?? 1,
        Endian.little,
      );
    return data.buffer.asUint8List();
  }

  static Uint8List _packChannelSelectUniforms(MaterialCompiledNodePass pass) {
    final data = ByteData(16)
      ..setInt32(
        0,
        _parameter(pass, 'channel_red').enumValue ?? 0,
        Endian.little,
      )
      ..setInt32(
        4,
        _parameter(pass, 'channel_green').enumValue ?? 1,
        Endian.little,
      )
      ..setInt32(
        8,
        _parameter(pass, 'channel_blue').enumValue ?? 2,
        Endian.little,
      )
      ..setInt32(
        12,
        _parameter(pass, 'channel_alpha').enumValue ?? 3,
        Endian.little,
      );
    return data.buffer.asUint8List();
  }

  static Uint8List _packMixUniforms(MaterialCompiledNodePass pass) {
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

  static GraphValueData _parameter(
    MaterialCompiledNodePass pass,
    String bindingKey,
  ) {
    return pass.parameterBindings
        .firstWhere((binding) => binding.bindingKey == bindingKey)
        .value;
  }
}
