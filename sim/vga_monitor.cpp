#include "vga_monitor.hpp"

#include <iostream>
#include <sstream>
#include <stdexcept>

namespace {
constexpr uint64_t kNominalFrameIntervalMs = 16;
}

VGAMonitor::VGAMonitor(bool headless, int scale)
    : sdl_ready_(false),
      headless_(headless),
      scale_(scale < 1 ? 1 : scale),
      window_(nullptr),
      renderer_(nullptr),
      texture_(nullptr),
      framebuffer_(),
      mode_{"unconfigured", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, true, true},
      configured_(false),
      prev_hsync_(true),
      prev_vsync_(true),
      saw_hsync_(false),
      saw_vsync_(false),
      frame_locked_(false),
      hsync_pulse_active_(false),
      vsync_pulse_active_(false),
      pixels_since_hsync_assert_(0),
      lines_since_vsync_assert_(0),
      line_from_vsync_(0),
      hsync_pulse_width_(0),
      vsync_pulse_lines_(0),
      frames_presented_(0),
      timing_errors_(0),
      frame_dirty_(false),
      quit_requested_(false),
      last_present_ms_(0) {
  if (headless_) {
    SDL_SetHint(SDL_HINT_VIDEODRIVER, "dummy");
  }

  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest");

  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    std::ostringstream oss;
    oss << "SDL_Init failed: " << SDL_GetError();
    throw std::runtime_error(oss.str());
  }

  sdl_ready_ = true;
}

VGAMonitor::~VGAMonitor() {
  destroyTargets();
  if (sdl_ready_) {
    SDL_Quit();
  }
}

void VGAMonitor::configure(const VideoMode& mode) {
  mode_ = mode;
  framebuffer_.assign(static_cast<size_t>(mode_.h_visible) * static_cast<size_t>(mode_.v_visible),
                      0xff000000u);
  configured_ = true;
  prev_hsync_ = mode_.hsync_active_low;
  prev_vsync_ = mode_.vsync_active_low;
  saw_hsync_ = false;
  saw_vsync_ = false;
  frame_locked_ = false;
  hsync_pulse_active_ = false;
  vsync_pulse_active_ = false;
  pixels_since_hsync_assert_ = 0;
  lines_since_vsync_assert_ = 0;
  line_from_vsync_ = 0;
  hsync_pulse_width_ = 0;
  vsync_pulse_lines_ = 0;
  frame_dirty_ = false;
  last_present_ms_ = 0;

  recreateTargets();
  std::cout << "[monitor] configured for " << mode_.name << '\n';
}

void VGAMonitor::tick(bool hsync, bool vsync, uint8_t red, uint8_t green, uint8_t blue) {
  if (!configured_) {
    prev_hsync_ = hsync;
    prev_vsync_ = vsync;
    return;
  }

  const bool prev_hsync_active = mode_.hsync_active_low ? !prev_hsync_ : prev_hsync_;
  const bool prev_vsync_active = mode_.vsync_active_low ? !prev_vsync_ : prev_vsync_;
  const bool hsync_active = mode_.hsync_active_low ? !hsync : hsync;
  const bool vsync_active = mode_.vsync_active_low ? !vsync : vsync;

  const bool hsync_assert = !prev_hsync_active && hsync_active;
  const bool hsync_deassert = prev_hsync_active && !hsync_active;
  const bool vsync_assert = !prev_vsync_active && vsync_active;
  const bool vsync_deassert = prev_vsync_active && !vsync_active;

  if (vsync_assert) {
    if (saw_vsync_ && lines_since_vsync_assert_ != mode_.v_total) {
      reportTimingError("frame line count mismatch", lines_since_vsync_assert_, mode_.v_total);
    }

    if (frame_dirty_) {
      presentFrame();
    }

    saw_vsync_ = true;
    frame_locked_ = true;
    vsync_pulse_active_ = true;
    vsync_pulse_lines_ = 0;
    lines_since_vsync_assert_ = 0;
    line_from_vsync_ = 0;
  }

  if (hsync_assert) {
    if (saw_hsync_ && pixels_since_hsync_assert_ != mode_.h_total) {
      reportTimingError("line pixel count mismatch", pixels_since_hsync_assert_, mode_.h_total);
    }

    saw_hsync_ = true;
    hsync_pulse_active_ = true;
    hsync_pulse_width_ = 0;
    pixels_since_hsync_assert_ = 0;

    if (saw_vsync_) {
      ++lines_since_vsync_assert_;
      ++line_from_vsync_;
      if (vsync_pulse_active_) {
        ++vsync_pulse_lines_;
      }
    }
  }

  if (hsync_deassert) {
    if (hsync_pulse_width_ != mode_.h_sync) {
      reportTimingError("hsync pulse width mismatch", hsync_pulse_width_, mode_.h_sync);
    }
    hsync_pulse_active_ = false;
  }

  if (vsync_deassert) {
    if (vsync_pulse_lines_ != mode_.v_sync) {
      reportTimingError("vsync pulse width mismatch", vsync_pulse_lines_, mode_.v_sync);
    }
    vsync_pulse_active_ = false;
  }

  if (frame_locked_ && saw_hsync_ && saw_vsync_) {
    const uint32_t visible_x_start = mode_.h_sync + mode_.h_back;
    const uint32_t visible_y_start = mode_.v_sync + mode_.v_back;
    const bool x_visible = (pixels_since_hsync_assert_ >= visible_x_start)
                        && (pixels_since_hsync_assert_ < visible_x_start + mode_.h_visible);
    const bool y_visible = (line_from_vsync_ >= visible_y_start)
                        && (line_from_vsync_ < visible_y_start + mode_.v_visible);

    if (x_visible && y_visible) {
      const uint32_t x = pixels_since_hsync_assert_ - visible_x_start;
      const uint32_t y = line_from_vsync_ - visible_y_start;
      framebuffer_[static_cast<size_t>(y) * mode_.h_visible + x] = packRgb(red, green, blue);
      frame_dirty_ = true;
    }
  }

  if (hsync_pulse_active_) {
    ++hsync_pulse_width_;
  }

  if (saw_hsync_) {
    ++pixels_since_hsync_assert_;
  }

  prev_hsync_ = hsync;
  prev_vsync_ = vsync;
}

uint32_t VGAMonitor::packRgb(uint8_t red, uint8_t green, uint8_t blue) {
  return 0xff000000u | (static_cast<uint32_t>(red) << 16) | (static_cast<uint32_t>(green) << 8)
       | static_cast<uint32_t>(blue);
}

void VGAMonitor::recreateTargets() {
  destroyTargets();

  if (headless_ || !configured_) {
    return;
  }

  window_ = SDL_CreateWindow(
      "VGA Monitor", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
      static_cast<int>(mode_.h_visible * static_cast<uint32_t>(scale_)),
      static_cast<int>(mode_.v_visible * static_cast<uint32_t>(scale_)), SDL_WINDOW_SHOWN);
  if (window_ == nullptr) {
    std::ostringstream oss;
    oss << "SDL_CreateWindow failed: " << SDL_GetError();
    throw std::runtime_error(oss.str());
  }

  renderer_ = SDL_CreateRenderer(window_, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (renderer_ == nullptr) {
    renderer_ = SDL_CreateRenderer(window_, -1, SDL_RENDERER_SOFTWARE);
  }
  if (renderer_ == nullptr) {
    std::ostringstream oss;
    oss << "SDL_CreateRenderer failed: " << SDL_GetError();
    throw std::runtime_error(oss.str());
  }

  texture_ = SDL_CreateTexture(renderer_, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
                               static_cast<int>(mode_.h_visible),
                               static_cast<int>(mode_.v_visible));
  if (texture_ == nullptr) {
    std::ostringstream oss;
    oss << "SDL_CreateTexture failed: " << SDL_GetError();
    throw std::runtime_error(oss.str());
  }

  SDL_RenderSetLogicalSize(renderer_, static_cast<int>(mode_.h_visible),
                           static_cast<int>(mode_.v_visible));
  SDL_SetWindowTitle(window_, mode_.name);
}

void VGAMonitor::destroyTargets() {
  if (texture_ != nullptr) {
    SDL_DestroyTexture(texture_);
    texture_ = nullptr;
  }
  if (renderer_ != nullptr) {
    SDL_DestroyRenderer(renderer_);
    renderer_ = nullptr;
  }
  if (window_ != nullptr) {
    SDL_DestroyWindow(window_);
    window_ = nullptr;
  }
}

void VGAMonitor::presentFrame() {
  if (!headless_) {
    if (texture_ == nullptr || renderer_ == nullptr) {
      throw std::runtime_error("SDL targets are not initialized");
    }

    SDL_UpdateTexture(texture_, nullptr, framebuffer_.data(),
                      static_cast<int>(mode_.h_visible * sizeof(uint32_t)));
    SDL_RenderClear(renderer_);
    SDL_RenderCopy(renderer_, texture_, nullptr, nullptr);
    SDL_RenderPresent(renderer_);

    const uint64_t now = SDL_GetTicks64();
    if (last_present_ms_ != 0 && (now - last_present_ms_) < kNominalFrameIntervalMs) {
      SDL_Delay(static_cast<uint32_t>(kNominalFrameIntervalMs - (now - last_present_ms_)));
    }
    last_present_ms_ = SDL_GetTicks64();
    pollEvents();
  }

  ++frames_presented_;
  frame_dirty_ = false;
}

void VGAMonitor::pollEvents() {
  SDL_Event event;
  while (SDL_PollEvent(&event) != 0) {
    if (event.type == SDL_QUIT) {
      quit_requested_ = true;
    }
  }
}

void VGAMonitor::reportTimingError(const std::string& message, uint64_t observed,
                                   uint64_t expected) {
  ++timing_errors_;
  std::cerr << "[monitor] " << message << ": observed=" << observed
            << " expected=" << expected << '\n';
}