// Catch2 entry point. JUCE GUI is initialised here so tests can use the
// MessageManager (APVTS, juce::Graphics, juce::Timer all need it).
#include "juce_gui_basics/juce_gui_basics.h"
#include <catch2/catch_session.hpp>

int main (int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI gui;
    return Catch::Session().run (argc, argv);
}
#include <catch2/catch_test_macros.hpp>
