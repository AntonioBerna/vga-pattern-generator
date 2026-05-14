/**
 * @interface video_pipeline_if
 * @brief Testbench interface for driving and monitoring video_pipeline_top.
 *
 * The interface mirrors the scalar DUT ports for simulator compatibility while
 * also providing clocking blocks and helper tasks that let the OOP testbench
 * apply grouped rate and timing configurations without repeating every scalar
 * assignment in the driver.
 * @param COLOR_W Bits per color channel.
 * @param COORD_W Width of the DUT timing and coordinate buses.
 * @param PATTERN_W Width of the pattern selection bus.
 * @param FRAMES_COUNTER_W Width of the pattern step counter.
 * @port clk Shared testbench clock.
 */
interface video_pipeline_if #(
    parameter int COLOR_W = 8,
    parameter int COORD_W = 16,
    parameter int PATTERN_W = 3,
    parameter int FRAMES_COUNTER_W = 16
) (
    input logic clk
);
  logic                        rst_i;
  logic                        use_external_pixel_tick_i;
  logic                        external_pixel_tick_i;
  logic                        rate_enable_i;
  logic [31:0]                 input_clk_hz_i;
  logic [31:0]                 pixel_clk_hz_i;
  logic                        pattern_auto_advance_i;
  logic                        hold_last_pattern_i;
  logic [FRAMES_COUNTER_W-1:0] frames_per_step_i;
  logic [PATTERN_W-1:0]        last_pattern_i;
  logic [PATTERN_W-1:0]        pattern_select_i;
  logic [COLOR_W-1:0]          solid_red_i;
  logic [COLOR_W-1:0]          solid_green_i;
  logic [COLOR_W-1:0]          solid_blue_i;
  logic [COORD_W-1:0]          h_visible_i;
  logic [COORD_W-1:0]          h_front_i;
  logic [COORD_W-1:0]          h_sync_i;
  logic [COORD_W-1:0]          h_back_i;
  logic [COORD_W-1:0]          v_visible_i;
  logic [COORD_W-1:0]          v_front_i;
  logic [COORD_W-1:0]          v_sync_i;
  logic [COORD_W-1:0]          v_back_i;
  logic                        hsync_active_low_i;
  logic                        vsync_active_low_i;

  logic [PATTERN_W-1:0]        active_pattern_o;
  logic                        pixel_tick_o;
  logic                        frame_start_o;
  logic                        frame_end_o;
  logic                        hsync_o;
  logic                        vsync_o;
  logic                        visible_o;
  logic [COLOR_W-1:0]          red_o;
  logic [COLOR_W-1:0]          green_o;
  logic [COLOR_W-1:0]          blue_o;
  logic [COORD_W-1:0]          x_o;
  logic [COORD_W-1:0]          y_o;
  logic                        stream_error_o;
  logic                        timing_error_o;
  logic                        rate_error_o;

  clocking drv_cb @(posedge clk);
    output rst_i;
    output use_external_pixel_tick_i;
    output external_pixel_tick_i;
    output rate_enable_i;
    output input_clk_hz_i;
    output pixel_clk_hz_i;
    output pattern_auto_advance_i;
    output hold_last_pattern_i;
    output frames_per_step_i;
    output last_pattern_i;
    output pattern_select_i;
    output solid_red_i;
    output solid_green_i;
    output solid_blue_i;
    output h_visible_i;
    output h_front_i;
    output h_sync_i;
    output h_back_i;
    output v_visible_i;
    output v_front_i;
    output v_sync_i;
    output v_back_i;
    output hsync_active_low_i;
    output vsync_active_low_i;
    input  active_pattern_o;
    input  pixel_tick_o;
    input  frame_start_o;
    input  frame_end_o;
    input  hsync_o;
    input  vsync_o;
    input  visible_o;
    input  red_o;
    input  green_o;
    input  blue_o;
    input  x_o;
    input  y_o;
    input  stream_error_o;
    input  timing_error_o;
    input  rate_error_o;
  endclocking

  clocking mon_cb @(posedge clk);
    input rst_i;
    input use_external_pixel_tick_i;
    input external_pixel_tick_i;
    input rate_enable_i;
    input input_clk_hz_i;
    input pixel_clk_hz_i;
    input pattern_auto_advance_i;
    input hold_last_pattern_i;
    input frames_per_step_i;
    input last_pattern_i;
    input pattern_select_i;
    input solid_red_i;
    input solid_green_i;
    input solid_blue_i;
    input h_visible_i;
    input h_front_i;
    input h_sync_i;
    input h_back_i;
    input v_visible_i;
    input v_front_i;
    input v_sync_i;
    input v_back_i;
    input hsync_active_low_i;
    input vsync_active_low_i;
    input active_pattern_o;
    input pixel_tick_o;
    input frame_start_o;
    input frame_end_o;
    input hsync_o;
    input vsync_o;
    input visible_o;
    input red_o;
    input green_o;
    input blue_o;
    input x_o;
    input y_o;
    input stream_error_o;
    input timing_error_o;
    input rate_error_o;
  endclocking

  task automatic drive_rate_cfg_cb(input video_types_pkg::video_rate_cfg_t rate_cfg);
    drv_cb.rate_enable_i <= rate_cfg.enable;
    drv_cb.input_clk_hz_i <= rate_cfg.input_clk_hz;
    drv_cb.pixel_clk_hz_i <= rate_cfg.pixel_clk_hz;
  endtask

  task automatic drive_timing_cfg_cb(input video_types_pkg::video_timing_cfg_t timing_cfg);
    drv_cb.h_visible_i <= COORD_W'(timing_cfg.h_visible);
    drv_cb.h_front_i <= COORD_W'(timing_cfg.h_front);
    drv_cb.h_sync_i <= COORD_W'(timing_cfg.h_sync);
    drv_cb.h_back_i <= COORD_W'(timing_cfg.h_back);
    drv_cb.v_visible_i <= COORD_W'(timing_cfg.v_visible);
    drv_cb.v_front_i <= COORD_W'(timing_cfg.v_front);
    drv_cb.v_sync_i <= COORD_W'(timing_cfg.v_sync);
    drv_cb.v_back_i <= COORD_W'(timing_cfg.v_back);
    drv_cb.hsync_active_low_i <= timing_cfg.hsync_active_low;
    drv_cb.vsync_active_low_i <= timing_cfg.vsync_active_low;
  endtask

  task automatic drive_idle();
    rst_i = 1'b1;
    use_external_pixel_tick_i = 1'b0;
    external_pixel_tick_i = 1'b0;
    rate_enable_i = 1'b0;
    input_clk_hz_i = 32'd100000000;
    pixel_clk_hz_i = 32'd25175000;
    pattern_auto_advance_i = 1'b0;
    hold_last_pattern_i = 1'b0;
    frames_per_step_i = '0;
    last_pattern_i = '0;
    pattern_select_i = '0;
    solid_red_i = '0;
    solid_green_i = '0;
    solid_blue_i = '0;
    h_visible_i = '0;
    h_front_i = '0;
    h_sync_i = '0;
    h_back_i = '0;
    v_visible_i = '0;
    v_front_i = '0;
    v_sync_i = '0;
    v_back_i = '0;
    hsync_active_low_i = 1'b1;
    vsync_active_low_i = 1'b1;
  endtask
endinterface