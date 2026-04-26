import Cocoa
import CoreVideo
import FlutterMacOS

private final class VulkanPreviewTextureSlot: NSObject, FlutterTexture {
  private let lock = NSLock()
  private var pixelBuffer: CVPixelBuffer?

  init(width: Int, height: Int) {
    super.init()
    pixelBuffer = Self.makePixelBuffer(width: width, height: height)
  }

  func update(width: Int, height: Int, bgraBytes: Data) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    let requiredByteCount = width * height * 4
    guard bgraBytes.count >= requiredByteCount else {
      return false
    }

    guard let nextPixelBuffer = Self.makePixelBuffer(width: width, height: height) else {
      return false
    }

    CVPixelBufferLockBaseAddress(nextPixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(nextPixelBuffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(nextPixelBuffer) else {
      return false
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(nextPixelBuffer)
    bgraBytes.withUnsafeBytes { rawBuffer in
      guard let sourceAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        return
      }
      let destinationAddress = baseAddress.assumingMemoryBound(to: UInt8.self)

      for row in 0..<height {
        let sourceOffset = row * width * 4
        let destinationOffset = row * bytesPerRow
        let sourceRow = sourceAddress.advanced(by: sourceOffset)
        let destinationRow = destinationAddress.advanced(by: destinationOffset)

        for column in 0..<width {
          let pixelOffset = column * 4
          let blue = Int(sourceRow[pixelOffset])
          let green = Int(sourceRow[pixelOffset + 1])
          let red = Int(sourceRow[pixelOffset + 2])
          let alpha = Int(sourceRow[pixelOffset + 3])

          // Flutter's macOS texture path expects premultiplied alpha.
          destinationRow[pixelOffset] = UInt8((blue * alpha + 127) / 255)
          destinationRow[pixelOffset + 1] = UInt8((green * alpha + 127) / 255)
          destinationRow[pixelOffset + 2] = UInt8((red * alpha + 127) / 255)
          destinationRow[pixelOffset + 3] = UInt8(alpha)
        }
      }
    }

    pixelBuffer = nextPixelBuffer
    return true
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    lock.lock()
    defer { lock.unlock() }

    guard let pixelBuffer else {
      return nil
    }

    return Unmanaged.passRetained(pixelBuffer)
  }

  private static func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attributes: [String: Any] = [
      kCVPixelBufferCGImageCompatibilityKey as String: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess else {
      return nil
    }
    return pixelBuffer
  }
}

private final class VulkanPreviewTexturePlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private let textures: FlutterTextureRegistry
  private var textureSlots: [Int64: VulkanPreviewTextureSlot] = [:]

  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: "eyecandy/vulkan_preview_texture",
      binaryMessenger: registrar.messenger
    )
    textures = registrar.textures
    super.init()
    registrar.addMethodCallDelegate(self, channel: channel)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    _ = VulkanPreviewTexturePlugin(registrar: registrar)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: "Expected arguments map.", details: nil))
      return
    }

    switch call.method {
    case "createTexture":
      createTexture(arguments: arguments, result: result)
    case "updateTexture":
      updateTexture(arguments: arguments, result: result)
    case "disposeTexture":
      disposeTexture(arguments: arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createTexture(arguments: [String: Any], result: @escaping FlutterResult) {
    let width = arguments["width"] as? Int ?? 1
    let height = arguments["height"] as? Int ?? 1
    let slot = VulkanPreviewTextureSlot(width: max(width, 1), height: max(height, 1))
    let textureId = textures.register(slot)
    guard textureId != 0 else {
      result(FlutterError(code: "register_failed", message: "Failed to register preview texture.", details: nil))
      return
    }
    textureSlots[textureId] = slot
    result(textureId)
  }

  private func updateTexture(arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let textureId = arguments["textureId"] as? Int64,
      let width = arguments["width"] as? Int,
      let height = arguments["height"] as? Int,
      let typedData = arguments["bytes"] as? FlutterStandardTypedData,
      let slot = textureSlots[textureId]
    else {
      result(FlutterError(code: "invalid_update", message: "Missing texture update data.", details: nil))
      return
    }

    guard slot.update(width: width, height: height, bgraBytes: typedData.data) else {
      result(FlutterError(code: "update_failed", message: "Failed to update preview texture.", details: nil))
      return
    }

    textures.textureFrameAvailable(textureId)
    result(nil)
  }

  private func disposeTexture(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let textureId = arguments["textureId"] as? Int64 else {
      result(FlutterError(code: "invalid_dispose", message: "Missing texture id.", details: nil))
      return
    }

    textures.unregisterTexture(textureId)
    textureSlots.removeValue(forKey: textureId)
    result(nil)
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    VulkanPreviewTexturePlugin.register(
      with: flutterViewController.registrar(forPlugin: "VulkanPreviewTexturePlugin")
    )

    super.awakeFromNib()
  }
}
