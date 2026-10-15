# Vendored Windows click-through dependency

- Upstream: https://github.com/hubacekjakub/Godot-WinMousePassthrough
- Pinned commit: `cb450b9d9618559b36aeedd4699dfbc5066bcbb1`
- License: MIT, included in `LICENSE`.
- Debug DLL SHA256: `0d4332bd492a13d6c248783dbd6f8c04dc99e80c0290a4335fe88a5edd113971`
- Release DLL SHA256: `9b27a1d6f5c3b4e5604900a3ed9bf071ae74bfe4116d21a30d758f85f804714f`
- Upstream C++ implementation and registration reviewed before integration.
- Loaded explicitly by `scripts/native_mouse.gd`; no editor plugin needed.
- `tools/package.gd` includes metadata in the PCK and copies both DLLs outside it.
- The current game's D3D12 renderer was tested with the extension. A separate OS process received clicks while the pet continued rendering on top.

Relevant engine issue: https://github.com/godotengine/godot/issues/120881
