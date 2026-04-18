import 'dart:typed_data';

import '../resources/preview_render_target.dart';
import 'preview_texture_bridge.dart';

class PreviewTextureRegistry {
  PreviewTextureRegistry({
    PreviewTextureBridge? bridge,
  }) : _bridge = bridge ?? PreviewTextureBridge.platform();

  final PreviewTextureBridge _bridge;
  final Map<String, PreviewTextureDescriptor> _descriptorsByKey =
      <String, PreviewTextureDescriptor>{};

  Future<PreviewTextureDescriptor?> updateTexture({
    required String key,
    required int width,
    required int height,
    required Uint8List bgraBytes,
  }) async {
    final existing = _descriptorsByKey[key];
    final descriptor = existing ??
        await _createTextureDescriptor(
          key: key,
          width: width,
          height: height,
        );
    if (descriptor == null) {
      return null;
    }

    await _bridge.updateTexture(
      textureId: descriptor.textureId,
      width: width,
      height: height,
      bgraBytes: bgraBytes,
    );
    final nextDescriptor = PreviewTextureDescriptor(
      textureId: descriptor.textureId,
      width: width,
      height: height,
    );
    _descriptorsByKey[key] = nextDescriptor;
    return nextDescriptor;
  }

  Future<void> releaseMissingKeys(Set<String> activeKeys) async {
    final staleKeys = _descriptorsByKey.keys
        .where((key) => !activeKeys.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      final descriptor = _descriptorsByKey.remove(key);
      if (descriptor == null) {
        continue;
      }
      await _bridge.disposeTexture(textureId: descriptor.textureId);
    }
  }

  Future<void> clear() => releaseMissingKeys(<String>{});

  Future<PreviewTextureDescriptor?> _createTextureDescriptor({
    required String key,
    required int width,
    required int height,
  }) async {
    final textureId = await _bridge.createTexture(
      key: key,
      width: width,
      height: height,
    );
    if (textureId == null || textureId == 0) {
      return null;
    }
    final descriptor = PreviewTextureDescriptor(
      textureId: textureId,
      width: width,
      height: height,
    );
    _descriptorsByKey[key] = descriptor;
    return descriptor;
  }
}
