#include "PluginEditor.h"

PluginEditor::PluginEditor (PluginProcessor& p)
    : juce::AudioProcessorEditor (&p), processorRef (p)
{
    nameLabel.setText (processorRef.getName(), juce::dontSendNotification);
    nameLabel.setJustificationType (juce::Justification::centred);
    nameLabel.setFont (juce::FontOptions (24.0f, juce::Font::bold));
    addAndMakeVisible (nameLabel);

    inspectButton.onClick = [this] { inspector.toggle(); };
    addAndMakeVisible (inspectButton);

    setSize (480, 320);
}

void PluginEditor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour::fromRGB (24, 24, 28));
}

void PluginEditor::resized()
{
    auto area = getLocalBounds().reduced (12);
    inspectButton.setBounds (area.removeFromBottom (28).removeFromRight (96));
    nameLabel.setBounds (area);
}
