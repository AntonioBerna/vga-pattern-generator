#pragma once

#include <SDL.h>

#include <cstdint>
#include <string>
#include <vector>

struct VideoMode {
  const char* name;
  uint32_t pixel_clock_hz;
  uint32_t h_visible;
  uint32_t h_front;
  uint32_t h_sync;
  uint32_t h_back;
  uint32_t h_total;
  uint32_t v_visible;
  uint32_t v_front;
  uint32_t v_sync;
  uint32_t v_back;
  uint32_t v_total;
  bool hsync_active_low;
  bool vsync_active_low;
};

class VGAMonitor {
 public:
  explicit VGAMonitor(bool headless = false, int scale = 1);
  ~VGAMonitor();

  void configure(const VideoMode& mode);
  void tick(bool hsync, bool vsync, uint8_t red, uint8_t green, uint8_t blue);

  bool quitRequested() const { return quit_requested_; }
  uint64_t framesPresented() const { return frames_presented_; }
  uint64_t timingErrors() const { return timing_errors_; }

 private:
  static uint32_t packRgb(uint8_t red, uint8_t green, uint8_t blue);

  void recreateTargets();
  void destroyTargets();
  void presentFrame();
  void pollEvents();
  void reportTimingError(const std::string& message, uint64_t observed, uint64_t expected);

  bool sdl_ready_;
  bool headless_;
  int scale_;
  SDL_Window* window_;
  SDL_Renderer* renderer_;
  SDL_Texture* texture_;
  std::vector<uint32_t> framebuffer_;
  VideoMode mode_;
  bool configured_;
  bool prev_hsync_;
  bool prev_vsync_;
  bool saw_hsync_;
  bool saw_vsync_;
  bool frame_locked_;
  bool hsync_pulse_active_;
  bool vsync_pulse_active_;
  uint32_t pixels_since_hsync_assert_;
  uint32_t lines_since_vsync_assert_;
  uint32_t line_from_vsync_;
  uint32_t hsync_pulse_width_;
  uint32_t vsync_pulse_lines_;
  uint64_t frames_presented_;
  uint64_t timing_errors_;
  bool frame_dirty_;
  bool quit_requested_;
  uint64_t last_present_ms_;
};