Vendored MoltenVK runtime for macOS app bundling.

- Source: Homebrew `molten-vk`
- Version: 1.4.1
- Bundled file: `libMoltenVK.dylib`

The macOS Runner target copies this dylib into the app bundle's
`Contents/Frameworks` directory so the Flutter app can load Vulkan through FFI
without relying on a system-wide MoltenVK install.
