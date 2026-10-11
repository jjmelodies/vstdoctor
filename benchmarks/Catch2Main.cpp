// Catch2 entry point for benchmarks. Mirrors tests/Catch2Main.cpp.
// Drop additional benchmarks/*.cpp files alongside this and #include them
// from here, or rely on cmake/Benchmarks.cmake's glob if you change it.
#include "juce_gui_basics/juce_gui_basics.h"
#include <catch2/catch_session.hpp>

int main (int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI gui;
    return Catch::Session().run (argc, argv);
}

#include <catch2/benchmark/catch_benchmark_all.hpp>
#include <catch2/catch_test_macros.hpp>

// Placeholder so catch_discover_tests() finds at least one entry. Drop a real
// `TEST_CASE("...", "[!benchmark]") { BENCHMARK("...") { ... }; }` here.
TEST_CASE ("benchmarks placeholder", "[benchmark]")
{
    SUCCEED();
}
