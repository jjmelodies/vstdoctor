#pragma once
#include <PluginProcessor.h>

// Run test code inside a live editor instance. Useful for snapshotting
// the GUI or driving timer callbacks.
[[maybe_unused]] static void runWithinPluginEditor (const std::function<void (PluginProcessor& plugin)>& testCode)
{
    PluginProcessor plugin;
    const auto editor = plugin.createEditorIfNeeded();
    testCode (plugin);
    plugin.editorBeingDeleted (editor);
    delete editor;
}
