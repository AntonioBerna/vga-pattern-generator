/**
 * @package video_types_pkg
 * @brief Shared runtime configuration types for the video pipeline RTL.
 *
 * Internal modules use these packed structs to exchange related clock and
 * timing configuration fields as typed bundles while the top-level interface
 * remains scalar and tool-friendly for synthesis, simulation, and C++ models.
 * @typedef video_cfg_word_t Normalized 32-bit field used for runtime configuration values.
 * @typedef video_rate_cfg_t Grouped clock-enable configuration for the rate generator.
 * @typedef video_timing_cfg_t Grouped raster timing configuration for the video sink.
 */
package video_types_pkg;
  typedef logic [31:0] video_cfg_word_t;

  typedef struct packed {
    logic            enable;
    video_cfg_word_t input_clk_hz;
    video_cfg_word_t pixel_clk_hz;
  } video_rate_cfg_t;

  typedef struct packed {
    video_cfg_word_t h_visible;
    video_cfg_word_t h_front;
    video_cfg_word_t h_sync;
    video_cfg_word_t h_back;
    video_cfg_word_t v_visible;
    video_cfg_word_t v_front;
    video_cfg_word_t v_sync;
    video_cfg_word_t v_back;
    logic            hsync_active_low;
    logic            vsync_active_low;
  } video_timing_cfg_t;
endpackage
