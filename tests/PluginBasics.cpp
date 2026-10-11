#include "helpers/test_helpers.h"
#include <PluginProcessor.h>
#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_string.hpp>

TEST_CASE ("Plugin instantiates", "[instance]")
{
    PluginProcessor plugin;
    REQUIRE (plugin.getName().isNotEmpty());
}

TEST_CASE ("processBlock produces no NaNs at default settings", "[dsp]")
{
    PluginProcessor plugin;
    plugin.prepareToPlay (44100.0, 512);

    juce::AudioBuffer<float> buffer (2, 512);
    buffer.clear();

    juce::MidiBuffer midi;
    plugin.processBlock (buffer, midi);

    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        for (int s = 0; s < buffer.getNumSamples(); ++s)
            REQUIRE (std::isfinite (buffer.getSample (ch, s)));
}
