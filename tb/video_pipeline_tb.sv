`timescale 1ns/1ps

/**
 * @module video_pipeline_tb
 * @brief OOP top-level testbench for video_pipeline_top.
 *
 * This module instantiates the testbench interface, the DUT, and the class-based
 * environment from `video_pipeline_tb_pkg`, then applies reset, starts the test,
 * dumps waveforms, and enforces a simulation timeout.
 */
module video_pipeline_tb;
  localparam int COLOR_W = 8;
  localparam int COORD_W = 16;
  localparam int PATTERN_W = 3;
  localparam int FRAMES_COUNTER_W = 16;

  logic clk;

  import video_pipeline_tb_pkg::*;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  video_pipeline_if #(
      .COLOR_W(COLOR_W),
      .COORD_W(COORD_W),
      .PATTERN_W(PATTERN_W),
      .FRAMES_COUNTER_W(FRAMES_COUNTER_W)
  ) _if (
      .clk(clk)
  );

  video_pipeline_top #(
      .COLOR_W(COLOR_W),
      .COORD_W(COORD_W),
      .PATTERN_W(PATTERN_W),
      .FRAMES_COUNTER_W(FRAMES_COUNTER_W)
  ) dut (
      .clk_i                   (clk),
      .rst_i                   (_if.rst_i),
      .use_external_pixel_tick_i(_if.use_external_pixel_tick_i),
      .external_pixel_tick_i   (_if.external_pixel_tick_i),
      .rate_enable_i           (_if.rate_enable_i),
      .input_clk_hz_i          (_if.input_clk_hz_i),
      .pixel_clk_hz_i          (_if.pixel_clk_hz_i),
      .pattern_auto_advance_i  (_if.pattern_auto_advance_i),
      .hold_last_pattern_i     (_if.hold_last_pattern_i),
      .frames_per_step_i       (_if.frames_per_step_i),
      .last_pattern_i          (_if.last_pattern_i),
      .pattern_select_i        (_if.pattern_select_i),
      .solid_red_i             (_if.solid_red_i),
      .solid_green_i           (_if.solid_green_i),
      .solid_blue_i            (_if.solid_blue_i),
      .h_visible_i             (_if.h_visible_i),
      .h_front_i               (_if.h_front_i),
      .h_sync_i                (_if.h_sync_i),
      .h_back_i                (_if.h_back_i),
      .v_visible_i             (_if.v_visible_i),
      .v_front_i               (_if.v_front_i),
      .v_sync_i                (_if.v_sync_i),
      .v_back_i                (_if.v_back_i),
      .hsync_active_low_i      (_if.hsync_active_low_i),
      .vsync_active_low_i      (_if.vsync_active_low_i),
      .active_pattern_o        (_if.active_pattern_o),
      .pixel_tick_o            (_if.pixel_tick_o),
      .frame_start_o           (_if.frame_start_o),
      .frame_end_o             (_if.frame_end_o),
      .hsync_o                 (_if.hsync_o),
      .vsync_o                 (_if.vsync_o),
      .visible_o               (_if.visible_o),
      .red_o                   (_if.red_o),
      .green_o                 (_if.green_o),
      .blue_o                  (_if.blue_o),
      .x_o                     (_if.x_o),
      .y_o                     (_if.y_o),
      .stream_error_o          (_if.stream_error_o),
      .timing_error_o          (_if.timing_error_o),
      .rate_error_o            (_if.rate_error_o)
  );

  initial begin
    test t0;

    _if.drive_idle();
    _if.rst_i <= 1'b1;
    repeat (5) @(posedge clk);
    _if.rst_i <= 1'b0;

    t0 = new();
    t0.e0.vif = _if;
    t0.run();

    repeat (20) @(posedge clk);
    $finish(1);
  end

  initial begin
    #1000000000 $fatal(1, "TIMEOUT: simulation did not finish within the limit.");
  end
endmodule