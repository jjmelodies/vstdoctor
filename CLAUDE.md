# Plugin Development Instructions

A JUCE 8 VST3 plugin built with the Pamplejuce stack (CMake + Ninja + MSVC). Real-time-safe: NO allocations, NO locks, NO system calls in `processBlock()` or anything it calls.

## Build commands

Builds use `Builds/` (Debug) or `BuildsRelease/` (Release). MSVC requires `vcvars64.bat` to have been sourced — launch from a "Developer Command Prompt for VS 2022" or use the bundled VS Code tasks.

```powershell
cmake -B Builds -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build Builds
ctest --test-dir Builds --output-on-failure
```

After a successful build, the VST3 is auto-copied to
`%LOCALAPPDATA%\Programs\Common\VST3\<ProductName>.vst3`.

## Layout

- `source/PluginProcessor.{h,cpp}` — `juce::AudioProcessor`. `processBlock` is the hot path.
- `source/PluginEditor.{h,cpp}` — JUCE `Component`. GUI thread; never blocks the audio thread.
- `tests/` — Catch2 unit tests. `Catch2Main.cpp` is the entry point.
- `cmake/` — submodule of `sudara/cmake-includes`. Don't edit; reusable helpers.
- `JUCE/` — submodule of `juce-framework/JUCE`. Don't edit.
- `modules/melatonin_inspector/` — debug GUI inspector.
- `packaging/` — Inno Setup script + icon.
- `tools/` — build/installer/manual scripts.

## Hard rules for real-time safety

1. No `new`, `malloc`, `std::vector::push_back`, `std::string`, `std::map`, etc. in `processBlock` or anything it calls. Pre-allocate buffers in `prepareToPlay`. For audio->GUI/message-thread comms use `juce::AbstractFifo` or `moodycamel::ReaderWriterQueue`.
2. No mutexes on the audio thread.
3. No I/O (file, network, logging). Use `juce::FileLogger` only from the message thread.
4. Assume `prepareToPlay` may be called multiple times with different sample rates and block sizes. Reallocate there only — never in `processBlock`.
5. Guard against denormals at the top of `processBlock`: `juce::ScopedNoDenormals noDenormals;`

## Parameters

All user parameters go through `juce::AudioProcessorValueTreeState` (APVTS). IDs declared in `source/PluginProcessor.h::ParamIDs`. Don't add parameters by any other route.

## Plugin metadata invariants

Product identity (`PRODUCT_NAME`, `COMPANY_NAME`, `BUNDLE_ID`, `PLUGIN_CODE`, `PLUGIN_MANUFACTURER_CODE`, formats, VST3 categories, `PLUGIN_SHAPE`) lives in `ProductConfig.cmake` at the repo root. Edit there, not in `CMakeLists.txt`.

Do NOT change the four-char codes, bundle ID, or installer `AppId` GUID without coordinating — host plugin databases and Add/Remove Programs key on them; a change orphans existing DAW projects and turns upgrades into parallel installs.

## Testing policy

- Add a Catch2 test for every DSP change.
- Run `pluginval.exe --strictness-level 10` before declaring a release-ready.
- Never break binary state format without bumping a state version property in `getStateInformation`/`setStateInformation`.

## Anti-patterns to refuse

- `malloc`/`new`/STL allocating containers in audio thread.
- `std::cout` or `DBG()` in `processBlock`.
- `juce::MessageManagerLock` on the audio thread.
- Editing files inside `JUCE/`, `cmake/`, or `modules/` (those are submodules).
