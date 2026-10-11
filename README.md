# JUCE VST Plugin Template

A JUCE 8 / Pamplejuce starting point for VST3 + Standalone audio plugins on Windows. Real-time-safe scaffolding, Catch2 tests, Inno Setup installer, and a single CMake variable that switches between four plugin shapes (audio FX, instrument, MIDI FX, audio-to-MIDI).

<!-- CI / license badges go here once GitHub Actions is wired up. -->

## Features

- JUCE 8 + CMake + Ninja + MSVC build, configured via [Pamplejuce](https://github.com/sudara/cmake-includes) helpers
- Four plugin shapes (`FX`, `Synth`, `MIDIFX`, `MIDIGen`) selected by one variable in [`ProductConfig.cmake`](ProductConfig.cmake)
- Real-time-safe processor scaffolding with hard rules enforced — see [`CLAUDE.md`](CLAUDE.md)
- Catch2 unit tests + a separate benchmarks target, both driven by `ctest`
- Single-command Windows installer pipeline ([`tools/build-installer.ps1`](tools/build-installer.ps1)) producing a signed-ready Inno Setup `.exe`
- Multi-shape validation: build all four shapes (and four installers) in one script, with transcripts saved under [`logs/`](logs/)
- Optional [Melatonin Inspector](https://github.com/sudara/melatonin_inspector) debug GUI overlay
- PDF user manual generated from [`docs/manual.md`](docs/manual.md) via Pandoc, with a Python `reportlab` fallback

## Quick start

```powershell
git clone --recurse-submodules https://github.com/exterminathan/JuceVSTTemplate.git MyPlugin
cd MyPlugin
```

Then, from a **Developer Command Prompt for VS 2022** (or any shell that has sourced `vcvars64.bat`):

```powershell
cmake -B Builds -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build Builds
ctest --test-dir Builds --output-on-failure
```

After a successful build, the VST3 is auto-copied to `%LOCALAPPDATA%\Programs\Common\VST3\<ProductName>.vst3` so your DAW can find it on the next rescan.

## Prerequisites

| Tool | Install |
|---|---|
| CMake ≥ 3.25 | `winget install Kitware.CMake` |
| Ninja | `winget install Ninja-build.Ninja` |
| Git | `winget install Git.Git` |
| Visual Studio 2022 (Desktop development with C++ workload) | install from Microsoft |
| Inno Setup 6 | `winget install JRSoftware.InnoSetup` |
| Pandoc *(optional, for manual PDF)* | `winget install JohnMacFarlane.Pandoc` |
| `reportlab` *(optional, fallback PDF)* | `pip install reportlab` |
| `pluginval.exe` *(optional, release validation)* | `pwsh -File tools\install-pluginval.ps1` |

Catch2 v3.8.1 is fetched at configure time via CPM — no separate install.

## Repository layout

```
├── source/              Plugin source (PluginProcessor, PluginEditor — replace with your DSP/GUI)
├── tests/               Catch2 unit tests
├── benchmarks/          Catch2 benchmark target
├── tools/               PowerShell + Python build, packaging, and validation scripts
├── packaging/           Inno Setup installer script + 512x512 icon
├── assets/              Images embedded as BinaryData at build time
├── docs/                Template documentation + end-user plugin manual
├── modules/             Third-party JUCE modules (melatonin_inspector submodule)
├── cmake/               Pamplejuce CMake helpers (submodule)
├── JUCE/                JUCE framework (submodule)
├── logs/                Build-script transcripts (gitignored)
├── Builds/              Debug build tree (gitignored)
├── BuildsRelease/       Release build tree (gitignored)
├── ProductConfig.cmake  Product identity + plugin shape (single source of truth)
├── VERSION              Plugin version string (e.g. 0.1.0)
├── CMakeLists.txt       Build entry point
├── CLAUDE.md            AI assistant instructions / project rules
├── LICENSE              MIT
└── README.md            This file
```

## Configure your plugin

All product identity lives in [`ProductConfig.cmake`](ProductConfig.cmake). Edit values there, not in [`CMakeLists.txt`](CMakeLists.txt):

```cmake
set(PRODUCT_NAME              "MyPlugin")           # Display name in DAW plugin browsers
set(PROJECT_NAME              "MyPlugin")           # CMake target name (no spaces)
set(COMPANY_NAME              "MyCompany")
set(BUNDLE_ID                 "com.mycompany.myplugin")
set(PLUGIN_MANUFACTURER_CODE  "MyCo")               # 4 chars, >=1 uppercase
set(PLUGIN_CODE               "Mplg")               # 4 chars, >=1 uppercase
set(PLUGIN_FORMATS            Standalone VST3)
set(PLUGIN_SHAPE              "Synth")              # FX | Synth | MIDIFX | MIDIGen
```

**Immutable once shipped.** The following identify your plugin in host plugin databases and the Windows Add/Remove Programs registry. Changing any of them after a public release orphans existing DAW projects and turns upgrades into duplicate installs:

- `PLUGIN_CODE`, `PLUGIN_MANUFACTURER_CODE`
- `BUNDLE_ID`
- The `AppId` GUID inside [`packaging/installer.iss`](packaging/installer.iss) — generate a fresh one with [`tools/regen-appid.ps1`](tools/regen-appid.ps1) **once**, before your first release.

See [`docs/QUICKSTART.md`](docs/QUICKSTART.md) for the full file-by-file checklist.

## Plugin shapes

Set `PLUGIN_SHAPE` in [`ProductConfig.cmake`](ProductConfig.cmake) and reconfigure ([`CMakeLists.txt`](CMakeLists.txt) expands it into the right `juce_add_plugin` flags).

| Shape | MIDI in | MIDI out | IS_SYNTH | IS_MIDI_EFFECT | Default category | Use case |
|---|---|---|---|---|---|---|
| `FX` | F | F | F | F | `Fx` | Reverb, EQ, distortion, compressor |
| `Synth` | T | F | T | F | `Instrument\|Synth` | MIDI in → audio out |
| `MIDIFX` | T | T | F | T | `Fx\|Tools` | Arpeggiator, harmonizer |
| `MIDIGen` | T | T | F | F | `Fx\|Analyzer` | Audio in → MIDI out (e.g. pitch detection) |

`MIDIGen` lives on an audio track in Ableton — `IS_SYNTH=FALSE` makes hosts treat it as an audio effect that happens to also emit MIDI.

## Build & test workflows

All commands assume you've sourced `vcvars64.bat` (Developer Command Prompt for VS 2022 does this for you).

**Debug build + tests:**

```powershell
cmake -B Builds -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build Builds
ctest --test-dir Builds --output-on-failure
```

**Release build:**

```powershell
cmake -B BuildsRelease -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build BuildsRelease
```

**Full installer pipeline** — configures Release, builds, runs `ctest`, regenerates the manual PDF, runs `iscc.exe`, and drops the final installer at `packaging\Output\<ProductName>-<Version>-Windows.exe`:

```powershell
pwsh -File tools\build-installer.ps1
```

Useful flags: `-SkipTests`, `-SkipManual`, `-SkipBuild` (re-run iscc against an existing build tree).

**Validate every plugin shape compiles** (uses a temporary build dir; restores [`ProductConfig.cmake`](ProductConfig.cmake) on Ctrl+C):

```powershell
pwsh -File tools\test-all-shapes.ps1
```

**Build a Release installer for every plugin shape:**

```powershell
pwsh -File tools\build-all-shape-installers.ps1
```

Both multi-shape scripts write a transcript into `logs/<script>-<timestamp>.log` by default. Pass `-NoLog` to suppress.

## Real-time safety

The audio thread runs `AudioProcessor::processBlock` under hard latency constraints. Anything you do there — directly or transitively — must obey:

1. **No allocation** in `processBlock` (no `new`/`malloc`/STL containers that grow).
2. **No mutexes** on the audio thread — use `juce::AbstractFifo` or a lock-free SPSC queue for cross-thread comms.
3. **No I/O** (files, network, logging, `DBG()`, `std::cout`) in `processBlock`.
4. `juce::ScopedNoDenormals noDenormals;` at the top of every `processBlock`.
5. Allocate buffers in `prepareToPlay` (called repeatedly with different sample rates and block sizes — reallocate there, never on the audio thread).

Full rule set, anti-patterns, and parameter-routing conventions live in [`CLAUDE.md`](CLAUDE.md).

## Forking — making it your own

When you start a new plugin from this template:

1. Clone with submodules: `git clone --recurse-submodules <url> MyPlugin`
2. Edit [`ProductConfig.cmake`](ProductConfig.cmake) — every field.
3. Edit [`VERSION`](VERSION) (e.g. `0.1.0`).
4. Run [`tools/regen-appid.ps1`](tools/regen-appid.ps1) **once** to mint a fresh installer GUID.
5. Replace [`assets/images/placeholder.png`](assets/images/placeholder.png) and [`packaging/icon.png`](packaging/icon.png).
6. Replace the stubs in [`source/PluginProcessor.{h,cpp}`](source/) and [`source/PluginEditor.{h,cpp}`](source/) with your DSP and GUI.
7. Edit [`docs/manual.md`](docs/manual.md) — this becomes the bundled user manual PDF.
8. If you don't want this template's git history: delete `.git/` and `git init` fresh, or `git rm --cached -r .` and re-add.
9. Optional: remove [`modules/melatonin_inspector`](modules/melatonin_inspector/) (and the matching [`.gitmodules`](.gitmodules) entry + `add_subdirectory` line in [`CMakeLists.txt`](CMakeLists.txt)) if you don't want the debug inspector.

[`docs/QUICKSTART.md`](docs/QUICKSTART.md) has the dense file-by-file version of this list.

## Documentation

- [`docs/QUICKSTART.md`](docs/QUICKSTART.md) — one-page setup reference (toolchain, submodules, file checklist, build commands)
- [`docs/manual.md`](docs/manual.md) — user manual stub for your plugin (rendered to `manual.pdf` and bundled into the installer)
- [`CLAUDE.md`](CLAUDE.md) — project rules, real-time-safety hard rules, AI assistant instructions

## Acknowledgments

- [Pamplejuce / sudara/cmake-includes](https://github.com/sudara/cmake-includes) — the CMake foundation this template builds on
- [JUCE](https://github.com/juce-framework/JUCE) — the audio plugin framework
- [Melatonin Inspector](https://github.com/sudara/melatonin_inspector) — debug GUI inspector
- [Catch2](https://github.com/catchorg/Catch2) — test framework
- [Inno Setup](https://jrsoftware.org/isinfo.php) — Windows installer compiler
- [pluginval](https://github.com/Tracktion/pluginval) — Tracktion's plugin validator

## License

[MIT](LICENSE).
