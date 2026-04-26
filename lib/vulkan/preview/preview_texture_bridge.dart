import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class PreviewTextureBridge {
  Future<int?> createTexture({
    required String key,
    required int width,
    required int height,
  });

  Future<void> updateTexture({
    required int textureId,
    required int width,
    required int height,
    required Uint8List bgraBytes,
  });

  Future<void> disposeTexture({
    required int textureId,
  });

  factory PreviewTextureBridge.platform() => const MethodChannelPreviewTextureBridge();
}

class MethodChannelPreviewTextureBridge implements PreviewTextureBridge {
  const MethodChannelPreviewTextureBridge();

  static const MethodChannel _channel = MethodChannel(
    'afro/vulkan_preview_texture',
  );

  @override
  Future<int?> createTexture({
    required String key,
    required int width,
    required int height,
  }) async {
    if (!defaultTargetPlatform.name.toLowerCase().contains('mac')) {
      return null;
    }
    return _channel.invokeMethod<int>('createTexture', <String, Object?>{
      'key': key,
      'width': width,
      'height': height,
    });
  }

  @override
  Future<void> updateTexture({
    required int textureId,
    required int width,
    required int height,
    required Uint8List bgraBytes,
  }) {
    return _channel.invokeMethod<void>('updateTexture', <String, Object?>{
      'textureId': textureId,
      'width': width,
      'height': height,
      'bytes': bgraBytes,
    });
  }

  @override
  Future<void> disposeTexture({
    required int textureId,
  }) {
    return _channel.invokeMethod<void>('disposeTexture', <String, Object?>{
      'textureId': textureId,
    });
  }
}
