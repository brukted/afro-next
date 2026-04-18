Vendored MoltenVK runtime for macOS app bundling.

- Source: official MoltenVK package from `https://github.com/KhronosGroup/MoltenVK`
- Bundled artifact: `MoltenVK/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib`
- Bundled file: `libMoltenVK.dylib`

The macOS Runner target copies this dylib into the app bundle's
`Contents/Frameworks` directory so the Flutter app can load Vulkan through FFI
without relying on a system-wide MoltenVK install.
