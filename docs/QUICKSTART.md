# Quickstart

One-page reference for setting up and using this template. Pairs with the root [README.md](../README.md), which is the higher-level overview.

## Stack

- **JUCE 8.0.x** — plugin framework (submodule)
- **CMake ≥ 3.25** — build orchestration
- **Ninja** — generator
- **MSVC v143** (VS 2022) — compiler
- **Catch2 v3.8.1** — tests, fetched via CPM at configure time
- **Inno Setup 6** — Windows installer
- **Pamplejuce** — sudara/cmake-includes submodule, drives the CMake helpers

## Required toolchain

```powershell
winget install Kitware.CMake
winget install Ninja-build.Ninja
winget install Git.Git
winget install JRSoftware.InnoSetup
# Visual Studio 2022 with the C++ workload — install manually
# Optional:
winget install JohnMacFarlane.Pandoc          # for docs/manual.pdf (preferred path)
pip install reportlab                          # PDF fallback
pwsh -File tools\install-pluginval.ps1         # downloads pluginval.exe into tools/
```

Always run builds from a **Developer Command Prompt for VS 2022** (or any shell that has sourced `vcvars64.bat`).

## Required submodules

| Path | URL | Purpose |
|---|---|---|
| `JUCE/` | `https://github.com/juce-framework/JUCE.git` | Framework |
| `cmake/` | `https://github.com/sudara/cmake-includes.git` | Pamplejuce CMake helpers |
| `modules/melatonin_inspector/` | `https://github.com/sudara/melatonin_inspector.git` | Debug GUI inspector |
| `modules/RTNeural/` (optional) | `https://github.com/jatinchowdhury18/RTNeural.git` | On-device neural inference |

If you cloned without `--recurse-submodules`:

```powershell
git submodule update --init --recursive
```

To add a fresh set from scratch:

```powershell
git submodule add https://github.com/juce-framework/JUCE.git JUCE
git submodule add https://github.com/sudara/cmake-includes.git cmake
git submodule add https://github.com/sudara/melatonin_inspector.git modules/melatonin_inspector
git submodule update --init --recursive
```

## File checklist

Legend: **[verbatim]** ship as-is · **[template]** edit values for your plugin · **[stub]** replace with your own content.

| File | Status | Purpose |
|---|---|---|
| [`ProductConfig.cmake`](../ProductConfig.cmake) | [template] | Single source of truth: name, codes, bundle ID, PLUGIN_SHAPE |
| [`VERSION`](../VERSION) | [template] | Single line, e.g. `0.1.0` |
| [`CMakeLists.txt`](../CMakeLists.txt) | [verbatim] | Build orchestration; expands PLUGIN_SHAPE → juce_add_plugin flags |
| [`.gitmodules`](../.gitmodules) | [template] | 3 entries (cmake, JUCE, melatonin_inspector); RTNeural commented out |
| [`.gitignore`](../.gitignore) | [verbatim] | Excludes Builds/, BuildsRelease/, _deps/, submodules, logs/, IDE noise |
| [`.gitattributes`](../.gitattributes) | [verbatim] | `* text=auto` |
| [`.clang-format`](../.clang-format) | [verbatim] | JUCE-style (Allman, 4-space) |
| [`source/PluginProcessor.h`](../source/PluginProcessor.h) / [`.cpp`](../source/PluginProcessor.cpp) | [stub] | Minimal AudioProcessor; replace with your DSP |
| [`source/PluginEditor.h`](../source/PluginEditor.h) / [`.cpp`](../source/PluginEditor.cpp) | [stub] | Minimal Component; replace with your GUI |
| [`tests/Catch2Main.cpp`](../tests/Catch2Main.cpp) | [verbatim] | Catch2 entry, JUCE GUI init |
| [`tests/helpers/test_helpers.h`](../tests/helpers/test_helpers.h) | [verbatim] | `runWithinPluginEditor` helper |
| [`tests/PluginBasics.cpp`](../tests/PluginBasics.cpp) | [stub] | Sanity test (instantiate + NaN-free processBlock) |
| [`packaging/installer.iss`](../packaging/installer.iss) | [template] | Inno Setup script; **regenerate AppId GUID before shipping** |
| [`packaging/icon.png`](../packaging/icon.png) | [stub] | Your 512×512 standalone icon |
| [`tools/build-installer.ps1`](../tools/build-installer.ps1) | [verbatim] | End-to-end packaging pipeline |
| [`tools/build-manual.ps1`](../tools/build-manual.ps1) | [verbatim] | Manual PDF generator (pandoc → reportlab fallback) |
| [`tools/build-manual-fallback.py`](../tools/build-manual-fallback.py) | [verbatim] | Python PDF fallback |
| [`docs/manual.md`](manual.md) | [stub] | End-user plugin manual; bundled into the installer as `manual.pdf` |
| [`.vscode/settings.json`](../.vscode/settings.json) | [verbatim] | CMake + IntelliSense config |
| [`.vscode/launch.json`](../.vscode/launch.json) | [template] | Replace `__PROJECT_NAME__` / `__PRODUCT_NAME__` placeholders |
| [`.vscode/tasks.json`](../.vscode/tasks.json) | [template] | Same — vcvars64.bat path may need adjusting for VS edition |
| [`CLAUDE.md`](../CLAUDE.md) | [verbatim] | Real-time-safety rules + project layout for AI assistants |
| `Builds/.gitkeep` | [verbatim] | Placeholder so Builds/ stays visible after .gitignore |
| `logs/.gitkeep` | [verbatim] | Same idea for the logs/ folder |

## Plugin shape cheat sheet

Set in [`ProductConfig.cmake`](../ProductConfig.cmake) as `PLUGIN_SHAPE`. CMakeLists expands it.

| Shape | MIDI in | MIDI out | IS_SYNTH | IS_MIDI_EFFECT | Default category | Use case |
|---|---|---|---|---|---|---|
| `FX` | F | F | F | F | `Fx` | Reverb, EQ, distortion, compressor |
| `Synth` | T | F | T | F | `Instrument\|Synth` | MIDI in → audio out |
| `MIDIFX` | T | T | F | T | `Fx\|Tools` | Arpeggiator, harmonizer |
| `MIDIGen` | T | T | F | F | `Fx\|Analyzer` | Audio in → MIDI out (e.g. pitch detection) |

`MIDIGen` lives on an audio track in Ableton — `IS_SYNTH=FALSE` makes hosts treat it as an audio effect that happens to also emit MIDI.

## Build commands

```powershell
# Debug
cmake -B Builds -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build Builds
ctest --test-dir Builds --output-on-failure

# Release
cmake -B BuildsRelease -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build BuildsRelease

# Full installer pipeline → packaging\Output\<ProductName>-<Version>-Windows.exe
pwsh -File tools\build-installer.ps1

# Validate every PLUGIN_SHAPE compiles (transcript saved under logs/)
pwsh -File tools\test-all-shapes.ps1

# Build a Release installer for every PLUGIN_SHAPE
pwsh -File tools\build-all-shape-installers.ps1
```

The multi-shape scripts write a transcript into `logs/<script>-<timestamp>.log` by default. Pass `-NoLog` to suppress.

## Real-time safety (non-negotiable)

1. No allocation in `processBlock` (no `new`/`malloc`/STL containers that grow).
2. No mutexes on the audio thread — use `juce::AbstractFifo`.
3. No I/O (files, logging, `DBG()`, `std::cout`) in `processBlock`.
4. `juce::ScopedNoDenormals noDenormals;` at the top of every `processBlock`.
5. Allocate buffers in `prepareToPlay` (called repeatedly with different SR/block size).

See [`CLAUDE.md`](../CLAUDE.md) for the full rule set and anti-patterns.

## Metadata invariants — once shipped, forever

- `PLUGIN_CODE`, `PLUGIN_MANUFACTURER_CODE` (both 4 chars, ≥1 uppercase)
- `BUNDLE_ID`
- `AppId` GUID in [`packaging/installer.iss`](../packaging/installer.iss) — regenerate with [`tools/regen-appid.ps1`](../tools/regen-appid.ps1) before your first release

Changing any of these post-release breaks existing DAW projects or splits Add/Remove Programs into duplicates.

## Forking this template

When you start a new plugin from this template:

1. `git clone --recurse-submodules <url> MyPlugin` and `cd MyPlugin`.
2. Edit [`ProductConfig.cmake`](../ProductConfig.cmake): `PRODUCT_NAME`, `PROJECT_NAME`, `COMPANY_NAME`, `BUNDLE_ID`, `PLUGIN_MANUFACTURER_CODE`, `PLUGIN_CODE`, `PLUGIN_FORMATS`, `PLUGIN_SHAPE`.
3. Edit [`VERSION`](../VERSION) (e.g. `0.1.0`).
4. Run [`tools/regen-appid.ps1`](../tools/regen-appid.ps1) to put a fresh GUID into the installer script. Do this **once**, before your first release; never again.
5. Replace [`assets/images/placeholder.png`](../assets/images/placeholder.png) (embedded as BinaryData) and [`packaging/icon.png`](../packaging/icon.png) (installer / standalone icon).
6. Replace the stubs in [`source/PluginProcessor.{h,cpp}`](../source/) and [`source/PluginEditor.{h,cpp}`](../source/) with your DSP and GUI.
7. Edit [`docs/manual.md`](manual.md) — this becomes the bundled user manual PDF.
8. If you don't want this template's git history, delete `.git/` and `git init` fresh, or `git rm --cached -r .` then re-add.
9. Optionally remove `modules/melatonin_inspector` (and the matching `.gitmodules` entry + `add_subdirectory` line in [`CMakeLists.txt`](../CMakeLists.txt)) if you don't want the debug inspector.
