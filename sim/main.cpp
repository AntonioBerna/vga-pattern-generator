#include "vga_monitor.hpp"

#include "Vvideo_pipeline_top.h"
#include "verilated.h"

#include <array>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
struct ScenarioStep {
  VideoMode mode;
  uint8_t pattern;
  const char* label;
};

struct Options {
  bool headless = false;
  uint32_t frames_per_step = 15;
  uint32_t input_clk_hz = 100000000; // 100 MHz
};

constexpr std::array<ScenarioStep, 6> kScenario = {{
    {{"640x480@60", 25175000, 640, 16, 96, 48, 800, 480, 10, 2, 33, 525, true, true},
     0,
     "solid color @ 640x480"},
    {{"640x480@60", 25175000, 640, 16, 96, 48, 800, 480, 10, 2, 33, 525, true, true},
     1,
     "vertical bars @ 640x480"},
    {{"800x600@60", 40000000, 800, 40, 128, 88, 1056, 600, 1, 4, 23, 628, false, false},
     2,
     "horizontal bars @ 800x600"},
    {{"800x600@60", 40000000, 800, 40, 128, 88, 1056, 600, 1, 4, 23, 628, false, false},
     4,
     "gradient RGB @ 800x600"},
    {{"1024x768@60", 65000000, 1024, 24, 136, 160, 1344, 768, 3, 6, 29, 806, true, true},
     3,
     "checkerboard @ 1024x768"},
    {{"1024x768@60", 65000000, 1024, 24, 136, 160, 1344, 768, 3, 6, 29, 806, true, true},
     5,
     "grid @ 1024x768"},
}};

void printUsage(const char* argv0) {
  std::cout << "Usage: " << argv0
            << " [--headless] [--frames-per-step N] [--input-clk-hz N]\n";
}

Options parseOptions(int argc, char** argv) {
  Options options;

  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    if (arg == "--headless") {
      options.headless = true;
    } else if (arg == "--frames-per-step") {
      if (i + 1 >= argc) {
        throw std::runtime_error("missing value after --frames-per-step");
      }
      options.frames_per_step = static_cast<uint32_t>(std::stoul(argv[++i]));
    } else if (arg == "--input-clk-hz") {
      if (i + 1 >= argc) {
        throw std::runtime_error("missing value after --input-clk-hz");
      }
      options.input_clk_hz = static_cast<uint32_t>(std::stoul(argv[++i]));
    } else if (arg == "--help") {
      printUsage(argv[0]);
      std::exit(0);
    } else {
      throw std::runtime_error("unknown option: " + arg);
    }
  }

  if (options.frames_per_step == 0) {
    throw std::runtime_error("--frames-per-step must be greater than zero");
  }

  if (options.input_clk_hz == 0) {
    throw std::runtime_error("--input-clk-hz must be greater than zero");
  }

  return options;
}

uint64_t computeMaxSystemClocks(const Options& options) {
  uint64_t total = 0;
  for (const auto& step : kScenario) {
    const auto& mode = step.mode;
    const uint64_t pixels_per_frame = static_cast<uint64_t>(mode.h_total) * mode.v_total;
    const uint64_t clocks_per_frame =
        ((pixels_per_frame * options.input_clk_hz) + mode.pixel_clock_hz - 1) / mode.pixel_clock_hz;
    total += static_cast<uint64_t>(options.frames_per_step + 2) * clocks_per_frame;
  }
  return total + (kScenario.size() * 32ull);
}

void tickDut(Vvideo_pipeline_top& dut, VGAMonitor& monitor) {
  dut.clk_i = 0;
  dut.eval();

  dut.clk_i = 1;
  dut.eval();

  if (dut.pixel_tick_o != 0) {
    monitor.tick(static_cast<bool>(dut.hsync_o), static_cast<bool>(dut.vsync_o),
                 static_cast<uint8_t>(dut.red_o), static_cast<uint8_t>(dut.green_o),
                 static_cast<uint8_t>(dut.blue_o));
  }
}

void applyScenarioStep(Vvideo_pipeline_top& dut, const ScenarioStep& step, uint32_t input_clk_hz) {
  dut.use_external_pixel_tick_i = 0;
  dut.external_pixel_tick_i = 0;
  dut.rate_enable_i = 1;
  dut.input_clk_hz_i = input_clk_hz;
  dut.pixel_clk_hz_i = step.mode.pixel_clock_hz;

  dut.pattern_auto_advance_i = 0;
  dut.hold_last_pattern_i = 0;
  dut.frames_per_step_i = 0;
  dut.last_pattern_i = 5;
  dut.pattern_select_i = step.pattern;

  dut.solid_red_i = 0x18u;
  dut.solid_green_i = 0x80u;
  dut.solid_blue_i = 0xf0u;

  dut.h_visible_i = step.mode.h_visible;
  dut.h_front_i = step.mode.h_front;
  dut.h_sync_i = step.mode.h_sync;
  dut.h_back_i = step.mode.h_back;
  dut.v_visible_i = step.mode.v_visible;
  dut.v_front_i = step.mode.v_front;
  dut.v_sync_i = step.mode.v_sync;
  dut.v_back_i = step.mode.v_back;
  dut.hsync_active_low_i = step.mode.hsync_active_low ? 1U : 0U;
  dut.vsync_active_low_i = step.mode.vsync_active_low ? 1U : 0U;
}
}  // namespace

int main(int argc, char** argv) {
  try {
    Verilated::commandArgs(argc, argv);
    const Options options = parseOptions(argc, argv);

    auto dut = std::make_unique<Vvideo_pipeline_top>();
    auto monitor = std::make_unique<VGAMonitor>(options.headless, 2);

    uint64_t system_clocks = 0;
    const uint64_t max_system_clocks = computeMaxSystemClocks(options);
    const uint64_t target_frames = static_cast<uint64_t>(options.frames_per_step) * kScenario.size();

    size_t step_index = 0;
    uint64_t completed_steps = 0;

    applyScenarioStep(*dut, kScenario.at(step_index), options.input_clk_hz);
    monitor->configure(kScenario.at(step_index).mode);
    std::cout << "[sim] step " << (step_index + 1) << "/" << kScenario.size() << ": "
              << kScenario.at(step_index).label << '\n';

    dut->clk_i = 0;
    dut->rst_i = 1;
    for (int i = 0; i < 8; ++i) {
      tickDut(*dut, *monitor);
      ++system_clocks;
    }
    dut->rst_i = 0;

    uint64_t step_frame_target = monitor->framesPresented() + options.frames_per_step;

    while (!Verilated::gotFinish() && !monitor->quitRequested() && monitor->framesPresented() < target_frames) {
      tickDut(*dut, *monitor);
      ++system_clocks;

      if (dut->stream_error_o != 0) {
        throw std::runtime_error("AXIS-to-VGA alignment error detected by the DUT");
      }

      if (dut->timing_error_o != 0) {
        throw std::runtime_error("invalid timing configuration detected by the DUT");
      }

      if (dut->rate_error_o != 0) {
        throw std::runtime_error("invalid pixel tick configuration detected by the DUT");
      }

      if (system_clocks > max_system_clocks) {
        throw std::runtime_error("simulation timeout while waiting for the scenario to complete");
      }

      if (monitor->framesPresented() >= step_frame_target) {
        ++completed_steps;
        if (completed_steps == kScenario.size()) {
          break;
        }

        step_index = static_cast<size_t>(completed_steps);
        applyScenarioStep(*dut, kScenario.at(step_index), options.input_clk_hz);
        monitor->configure(kScenario.at(step_index).mode);
        std::cout << "[sim] step " << (step_index + 1) << "/" << kScenario.size() << ": "
                  << kScenario.at(step_index).label << '\n';

        dut->rst_i = 1;
        for (int i = 0; i < 8; ++i) {
          tickDut(*dut, *monitor);
          ++system_clocks;
        }
        dut->rst_i = 0;
        step_frame_target = monitor->framesPresented() + options.frames_per_step;
      }
    }

    if (completed_steps != kScenario.size()) {
      throw std::runtime_error("the DUT did not complete the full scenario");
    }

    std::cout << "[sim] frames presented: " << monitor->framesPresented() << '\n';
    std::cout << "[sim] timing errors: " << monitor->timingErrors() << '\n';

    if (monitor->timingErrors() != 0) {
      return 1;
    }

    return 0;
  } catch (const std::exception& ex) {
    std::cerr << "[sim] error: " << ex.what() << '\n';
    return 1;
  }
}