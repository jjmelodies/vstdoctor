# ProductConfig.cmake -- single source of truth for product identity + plugin shape.
#
# Edit values here to rename. Do NOT scatter copies of these strings through
# CMakeLists.txt or source files -- re-derive from these variables.

# Display name shown in DAW plugin browsers (spaces allowed).
set(PRODUCT_NAME              "MyPlugin")

# Internal CMake project / target name (no spaces).
set(PROJECT_NAME              "MyPlugin")

# Publisher / manufacturer name shown in plugin browsers.
set(COMPANY_NAME              "MyCompany")

# Reverse-DNS bundle identifier (used on macOS; harmless on Windows).
set(BUNDLE_ID                 "com.mycompany.myplugin")

# 4-char manufacturer code -- must contain >=1 uppercase letter.
# Persisted in host plugin DBs; changing post-release breaks existing DAW projects.
set(PLUGIN_MANUFACTURER_CODE  "MyCo")

# 4-char plugin code -- same rules and warning as above.
set(PLUGIN_CODE               "Mplg")

# Build outputs. Valid: AAX Unity VST VST3 AU AUv3 Standalone.
set(PLUGIN_FORMATS            Standalone VST3)

# Plugin shape -- one of: FX, Synth, MIDIFX, MIDIGen.
#   FX       -- Audio effect (reverb, EQ, distortion, compressor).
#   Synth    -- Instrument: MIDI in -> audio out.
#   MIDIFX   -- MIDI effect: MIDI in -> MIDI out, no audio.
#   MIDIGen  -- Audio in -> MIDI out (e.g. pitch-to-MIDI, beat detection).
set(PLUGIN_SHAPE              "Synth")

# Optional VST3 category override. If unset, CMakeLists picks a sensible
# default per shape. Pipe-separated: "Instrument|Synth", "Fx|EQ", etc.
# set(VST3_CATEGORIES         "Fx|EQ")
