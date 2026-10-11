#pragma once
#include "PluginProcessor.h"
#include "melatonin_inspector/melatonin_inspector.h"

class PluginEditor : public juce::AudioProcessorEditor
{
public:
    explicit PluginEditor (PluginProcessor&);
    ~PluginEditor() override = default;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    PluginProcessor& processorRef;

    juce::Label nameLabel;
    juce::TextButton inspectButton { "Inspect" };
    melatonin::Inspector inspector { *this };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PluginEditor)
};
