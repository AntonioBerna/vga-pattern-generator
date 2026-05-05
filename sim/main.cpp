#include "vga_monitor.h"

#include "Vvideo_pipeline_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

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
  uint8_t mode;
  uint8_t pattern;
  const char* label;
};

struct Options {
  bool headless = false;
  bool trace = false;
  uint32_t frames_per_step = 15;
};

constexpr std::array<VideoMode, 3> kVideoModes = {{
    {"640x480@60", 640, 16, 96, 48, 800, 480, 10, 2, 33, 525},
    {"800x600@60", 800, 40, 128, 88, 1056, 600, 1, 4, 23, 628},
    {"1024x768@60", 1024, 24, 136, 160, 1344, 768, 3, 6, 29, 806},
}};

constexpr std::array<ScenarioStep, 6> kScenario = {{
    {0, 0, "solid color @ 640x480"},
    {0, 1, "vertical bars @ 640x480"},
    {1, 2, "horizontal bars @ 800x600"},
    {1, 4, "gradient RGB @ 800x600"},
    {2, 3, "checkerboard @ 1024x768"},
    {2, 5, "grid @ 1024x768"},
}};

void printUsage(const char* argv0) {
  std::cout << "Usage: " << argv0 << " [--headless] [--trace] [--frames-per-step N]\n";
}

Options parseOptions(int argc, char** argv) {
  Options options;

  for (int i = 1; i < argc; ++i) {
    const std::string arg = argv[i];
    if (arg == "--headless") {
      options.headless = true;
    } else if (arg == "--trace") {
      options.trace = true;
    } else if (arg == "--frames-per-step") {
      if (i + 1 >= argc) {
        throw std::runtime_error("missing value after --frames-per-step");
      }
      options.frames_per_step = static_cast<uint32_t>(std::stoul(argv[++i]));
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

  return options;
}

void applyScenarioStep(Vvideo_pipeline_top& dut, const ScenarioStep& step, size_t index) {
  dut.mode_select_i = step.mode;
  dut.pattern_select_i = step.pattern;
  std::cout << "[sim] step " << (index + 1) << "/" << kScenario.size() << ": " << step.label
            << '\n';
}

uint64_t computeMaxPixelClocks(uint32_t frames_per_step) {
  uint64_t total = 0;
  for (const auto& step : kScenario) {
    const auto& mode = kVideoModes.at(step.mode);
    total += static_cast<uint64_t>(frames_per_step + 2) * mode.h_total * mode.v_total;
  }
  return total;
}

void tickDut(Vvideo_pipeline_top& dut, VerilatedVcdC* trace, uint64_t& sim_time,
             VGAMonitor& monitor, uint8_t& monitor_mode) {
  dut.clk_i = 0;
  dut.eval();
  if (trace != nullptr) {
    trace->dump(sim_time++);
  }

  dut.clk_i = 1;
  dut.eval();
  if (trace != nullptr) {
    trace->dump(sim_time++);
  }

  const uint8_t active_mode = static_cast<uint8_t>(dut.active_mode_o & 0x3u);
  if (active_mode < kVideoModes.size() && active_mode != monitor_mode) {
    monitor.configure(kVideoModes.at(active_mode));
    monitor_mode = active_mode;
  }

  monitor.tick(static_cast<bool>(dut.hsync_o), static_cast<bool>(dut.vsync_o),
               static_cast<uint8_t>(dut.red_o), static_cast<uint8_t>(dut.green_o),
               static_cast<uint8_t>(dut.blue_o));
}
}  // namespace

int main(int argc, char** argv) {
  try {
    Verilated::commandArgs(argc, argv);
    const Options options = parseOptions(argc, argv);

    auto dut = std::make_unique<Vvideo_pipeline_top>();
    auto monitor = std::make_unique<VGAMonitor>(options.headless, 2);

    std::unique_ptr<VerilatedVcdC> trace;
    if (options.trace) {
      Verilated::traceEverOn(true);
      trace = std::make_unique<VerilatedVcdC>();
      dut->trace(trace.get(), 99);
      trace->open("build/waveform.vcd");
    }

    uint64_t sim_time = 0;
    uint64_t pixel_clocks = 0;
    const uint64_t max_pixel_clocks = computeMaxPixelClocks(options.frames_per_step);

    size_t step_index = 0;
    uint64_t step_start_frame = 0;
    uint8_t monitor_mode = 0xffu;

    dut->clk_i = 0;
    dut->rst_i = 1;
    applyScenarioStep(*dut, kScenario.at(step_index), step_index);
    for (int i = 0; i < 8; ++i) {
      tickDut(*dut, trace.get(), sim_time, *monitor, monitor_mode);
      ++pixel_clocks;
    }
    dut->rst_i = 0;

    while (!Verilated::gotFinish() && !monitor->quitRequested() && step_index < kScenario.size()) {
      tickDut(*dut, trace.get(), sim_time, *monitor, monitor_mode);
      ++pixel_clocks;

      if (dut->stream_error_o != 0) {
        throw std::runtime_error("AXIS-to-VGA alignment error detected by the DUT");
      }

      if (pixel_clocks > max_pixel_clocks) {
        throw std::runtime_error("simulation timeout while waiting for the scenario to complete");
      }

      if ((monitor->framesPresented() - step_start_frame) >= options.frames_per_step) {
        ++step_index;
        if (step_index < kScenario.size()) {
          step_start_frame = monitor->framesPresented();
          applyScenarioStep(*dut, kScenario.at(step_index), step_index);
        }
      }
    }

    if (trace != nullptr) {
      trace->close();
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