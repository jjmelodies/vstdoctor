cmake_minimum_required(VERSION 3.25)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(PamplejuceVersion)
include(CPM)
include(PamplejuceMacOS)
include(JUCEDefaults)

# Single source of truth for product identity + plugin shape.
include("${CMAKE_CURRENT_SOURCE_DIR}/ProductConfig.cmake")

# sccache-friendly debug info: embed (/Z7) instead of separate .pdb.
set(CMAKE_POLICY_DEFAULT_CMP0141        NEW      CACHE STRING "" FORCE)
set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded CACHE STRING "" FORCE)

project(${PROJECT_NAME} VERSION ${CURRENT_VERSION})

include(PamplejuceLog)

# JUCE itself (submodule).
add_subdirectory(JUCE)

# Optional GUI inspector (submodule). Remove this line and the corresponding
# .gitmodules entry if you don't want it.
add_subdirectory(modules/melatonin_inspector)

# Optional: RTNeural for on-device ML inference.
# Uncomment, add the .gitmodules entry, and `git submodule add` to enable.
# set(RTNEURAL_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
# set(RTNEURAL_BUILD_BENCH    OFF CACHE BOOL "" FORCE)
# set(RTNEURAL_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
# add_subdirectory(modules/RTNeural)

# Plugin shape -> juce_add_plugin flags.
if (PLUGIN_SHAPE STREQUAL "FX")
    set(_NEEDS_MIDI_INPUT  FALSE)
    set(_NEEDS_MIDI_OUTPUT FALSE)
    set(_IS_SYNTH          FALSE)
    set(_IS_MIDI_EFFECT    FALSE)
    if (NOT VST3_CATEGORIES)
        set(VST3_CATEGORIES "Fx")
    endif()
elseif (PLUGIN_SHAPE STREQUAL "Synth")
    set(_NEEDS_MIDI_INPUT  TRUE)
    set(_NEEDS_MIDI_OUTPUT FALSE)
    set(_IS_SYNTH          TRUE)
    set(_IS_MIDI_EFFECT    FALSE)
    if (NOT VST3_CATEGORIES)
        set(VST3_CATEGORIES "Instrument|Synth")
    endif()
elseif (PLUGIN_SHAPE STREQUAL "MIDIFX")
    set(_NEEDS_MIDI_INPUT  TRUE)
    set(_NEEDS_MIDI_OUTPUT TRUE)
    set(_IS_SYNTH          FALSE)
    set(_IS_MIDI_EFFECT    TRUE)
    if (NOT VST3_CATEGORIES)
        set(VST3_CATEGORIES "Fx|Tools")
    endif()
elseif (PLUGIN_SHAPE STREQUAL "MIDIGen")
    set(_NEEDS_MIDI_INPUT  TRUE)
    set(_NEEDS_MIDI_OUTPUT TRUE)
    set(_IS_SYNTH          FALSE)
    set(_IS_MIDI_EFFECT    FALSE)
    if (NOT VST3_CATEGORIES)
        set(VST3_CATEGORIES "Fx|Analyzer")
    endif()
else()
    message(FATAL_ERROR "PLUGIN_SHAPE must be one of: FX, Synth, MIDIFX, MIDIGen")
endif()

juce_add_plugin("${PROJECT_NAME}"
    ICON_BIG "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icon.png"
    COMPANY_NAME "${COMPANY_NAME}"
    BUNDLE_ID "${BUNDLE_ID}"
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE "${PLUGIN_MANUFACTURER_CODE}"
    PLUGIN_CODE "${PLUGIN_CODE}"
    FORMATS "${PLUGIN_FORMATS}"
    NEEDS_MIDI_INPUT  "${_NEEDS_MIDI_INPUT}"
    NEEDS_MIDI_OUTPUT "${_NEEDS_MIDI_OUTPUT}"
    IS_MIDI_EFFECT    "${_IS_MIDI_EFFECT}"
    IS_SYNTH          "${_IS_SYNTH}"
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    VST3_CATEGORIES "${VST3_CATEGORIES}"
    VST3_COPY_DIR "$ENV{LOCALAPPDATA}/Programs/Common/VST3"
    PRODUCT_NAME "${PRODUCT_NAME}")

# Shared INTERFACE library so plugin and tests can link the same TUs
# without ODR violations.
add_library(SharedCode INTERFACE)
include(SharedCodeDefaults)

# Glob source. CONFIGURE_DEPENDS makes ninja re-glob when files appear.
file(GLOB_RECURSE SourceFiles CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/source/*.h")
target_sources(SharedCode INTERFACE ${SourceFiles})

# assets/ folder embedded as BinaryData::* in the build.
include(Assets)

include(XcodePrettify)

target_compile_definitions(SharedCode INTERFACE
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
    JUCE_REPORT_APP_USAGE=0
    CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    VERSION="${CURRENT_VERSION}"
    PRODUCT_NAME_WITHOUT_VERSION="${PRODUCT_NAME}")

target_link_libraries(SharedCode INTERFACE
    Assets
    melatonin_inspector
    juce_audio_utils
    juce_audio_processors
    juce_dsp
    juce_gui_basics
    juce_gui_extra
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags)

target_link_libraries("${PROJECT_NAME}" PRIVATE SharedCode)

include(PamplejuceIPP)
include(Tests)
include(Benchmarks)
include(GitHubENV)
