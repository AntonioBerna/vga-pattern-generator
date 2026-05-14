`timescale 1ns/1ps

/**
 * @module video_pipeline_verilator_tb
 * @brief Procedural Verilator-oriented testbench for video_pipeline_top.
 *
 * The testbench runs a deterministic set of timing and pattern scenarios,
 * checks frame geometry and sampled pixels, and validates that the generic RTL
 * still behaves correctly under the Makefile-driven Verilator flow.
 */
module video_pipeline_verilator_tb;
  localparam int COLOR_W = 8;
  localparam int COORD_W = 16;
  localparam int PATTERN_W = 3;
  localparam int FRAMES_COUNTER_W = 16;
  localparam int SAMPLE_COUNT = 5;

  typedef struct packed {
    video_types_pkg::video_rate_cfg_t   rate_cfg;
    video_types_pkg::video_timing_cfg_t timing_cfg;
  } video_mode_cfg_t;

  logic                        clk;
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
  int                          pass_cnt;

  video_pipeline_top #(
      .COLOR_W(COLOR_W),
      .COORD_W(COORD_W),
      .PATTERN_W(PATTERN_W),
      .FRAMES_COUNTER_W(FRAMES_COUNTER_W)
  ) dut (
      .clk_i                   (clk),
      .rst_i                   (rst_i),
      .use_external_pixel_tick_i(use_external_pixel_tick_i),
      .external_pixel_tick_i   (external_pixel_tick_i),
      .rate_enable_i           (rate_enable_i),
      .input_clk_hz_i          (input_clk_hz_i),
      .pixel_clk_hz_i          (pixel_clk_hz_i),
      .pattern_auto_advance_i  (pattern_auto_advance_i),
      .hold_last_pattern_i     (hold_last_pattern_i),
      .frames_per_step_i       (frames_per_step_i),
      .last_pattern_i          (last_pattern_i),
      .pattern_select_i        (pattern_select_i),
      .solid_red_i             (solid_red_i),
      .solid_green_i           (solid_green_i),
      .solid_blue_i            (solid_blue_i),
      .h_visible_i             (h_visible_i),
      .h_front_i               (h_front_i),
      .h_sync_i                (h_sync_i),
      .h_back_i                (h_back_i),
      .v_visible_i             (v_visible_i),
      .v_front_i               (v_front_i),
      .v_sync_i                (v_sync_i),
      .v_back_i                (v_back_i),
      .hsync_active_low_i      (hsync_active_low_i),
      .vsync_active_low_i      (vsync_active_low_i),
      .active_pattern_o        (active_pattern_o),
      .pixel_tick_o            (pixel_tick_o),
      .frame_start_o           (frame_start_o),
      .frame_end_o             (frame_end_o),
      .hsync_o                 (hsync_o),
      .vsync_o                 (vsync_o),
      .visible_o               (visible_o),
      .red_o                   (red_o),
      .green_o                 (green_o),
      .blue_o                  (blue_o),
      .x_o                     (x_o),
      .y_o                     (y_o),
      .stream_error_o          (stream_error_o),
      .timing_error_o          (timing_error_o),
      .rate_error_o            (rate_error_o)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  function automatic string scenario_name(input int unsigned scenario_idx);
    begin
      unique case (scenario_idx)
        0: return "manual solid/internal tick";
        1: return "manual vertical/internal tick";
        2: return "manual gradient/external tick";
        default: return "auto sequence hold-last";
      endcase
    end
  endfunction

  function automatic int unsigned scenario_mode_index(input int unsigned scenario_idx);
    begin
      unique case (scenario_idx)
        0: return 0;
        1: return 1;
        2: return 2;
        default: return 0;
      endcase
    end
  endfunction

  function automatic video_mode_cfg_t get_mode_cfg(input int unsigned mode_idx);
    video_mode_cfg_t mode_cfg;
    begin
      unique case (mode_idx)
        0: begin
          mode_cfg.rate_cfg = '{enable: 1'b1, input_clk_hz: 32'd100000000,
                                pixel_clk_hz: 32'd25175000};
          mode_cfg.timing_cfg = '{h_visible: 32'd640, h_front: 32'd16, h_sync: 32'd96,
                                  h_back: 32'd48, v_visible: 32'd480, v_front: 32'd10,
                                  v_sync: 32'd2, v_back: 32'd33, hsync_active_low: 1'b1,
                                  vsync_active_low: 1'b1};
        end
        1: begin
          mode_cfg.rate_cfg = '{enable: 1'b1, input_clk_hz: 32'd100000000,
                                pixel_clk_hz: 32'd40000000};
          mode_cfg.timing_cfg = '{h_visible: 32'd800, h_front: 32'd40, h_sync: 32'd128,
                                  h_back: 32'd88, v_visible: 32'd600, v_front: 32'd1,
                                  v_sync: 32'd4, v_back: 32'd23, hsync_active_low: 1'b0,
                                  vsync_active_low: 1'b0};
        end
        default: begin
          mode_cfg.rate_cfg = '{enable: 1'b1, input_clk_hz: 32'd100000000,
                                pixel_clk_hz: 32'd65000000};
          mode_cfg.timing_cfg = '{h_visible: 32'd1024, h_front: 32'd24, h_sync: 32'd136,
                                  h_back: 32'd160, v_visible: 32'd768, v_front: 32'd3,
                                  v_sync: 32'd6, v_back: 32'd29, hsync_active_low: 1'b1,
                                  vsync_active_low: 1'b1};
        end
      endcase
      return mode_cfg;
    end
  endfunction

  function automatic int unsigned expected_h_total(input int unsigned scenario_idx);
    int unsigned mode_idx;
    video_mode_cfg_t current_mode;
    begin
      mode_idx = scenario_mode_index(scenario_idx);
      current_mode = get_mode_cfg(mode_idx);
      return int'(current_mode.timing_cfg.h_visible) + int'(current_mode.timing_cfg.h_front)
           + int'(current_mode.timing_cfg.h_sync) + int'(current_mode.timing_cfg.h_back);
    end
  endfunction

  function automatic int unsigned expected_v_total(input int unsigned scenario_idx);
    int unsigned mode_idx;
    video_mode_cfg_t current_mode;
    begin
      mode_idx = scenario_mode_index(scenario_idx);
      current_mode = get_mode_cfg(mode_idx);
      return int'(current_mode.timing_cfg.v_visible) + int'(current_mode.timing_cfg.v_front)
           + int'(current_mode.timing_cfg.v_sync) + int'(current_mode.timing_cfg.v_back);
    end
  endfunction

  function automatic int unsigned frames_to_check(input int unsigned scenario_idx);
    begin
      unique case (scenario_idx)
        0: return 2;
        1: return 1;
        2: return 1;
        default: return 7;
      endcase
    end
  endfunction

  function automatic logic [PATTERN_W-1:0] expected_pattern(input int unsigned scenario_idx,
                                                            input int unsigned frame_idx);
    begin
      unique case (scenario_idx)
        0: return PATTERN_W'(0);
        1: return PATTERN_W'(1);
        2: return PATTERN_W'(4);
        default: begin
          if (frame_idx < 6) begin
            return PATTERN_W'(frame_idx);
          end
          return PATTERN_W'(5);
        end
      endcase
    end
  endfunction

  function automatic logic [COLOR_W-1:0] from_u8(input logic [7:0] value);
    return COLOR_W'(((64'(value) * (((64'd1 << COLOR_W) - 1))) + 64'd127) / 64'd255);
  endfunction

  function automatic logic [COLOR_W-1:0] scale_to_channel(
      input longint unsigned value,
      input longint unsigned span
  );
    begin
      if (span <= 1) begin
        return '0;
      end
      return COLOR_W'((value * (((64'd1 << COLOR_W) - 1))) / (span - 1));
    end
  endfunction

  function automatic logic [(3*COLOR_W)-1:0] expected_rgb(
      input logic [PATTERN_W-1:0] pattern,
      input int unsigned          x,
      input int unsigned          y,
      input int unsigned          scenario_idx
  );
    int unsigned         mode_idx;
    video_mode_cfg_t     current_mode;
    longint unsigned     x_value;
    longint unsigned     y_value;
    longint unsigned     width_value;
    longint unsigned     height_value;
    int unsigned         vertical_bin;
    int unsigned         horizontal_bin;
    logic [COLOR_W-1:0]  red;
    logic [COLOR_W-1:0]  green;
    logic [COLOR_W-1:0]  blue;
    bit                  checker_on;
    bit                  grid_on;
    begin
      mode_idx = scenario_mode_index(scenario_idx);
      current_mode = get_mode_cfg(mode_idx);
      x_value = 64'(x);
      y_value = 64'(y);
      width_value = 64'(current_mode.timing_cfg.h_visible);
      height_value = 64'(current_mode.timing_cfg.v_visible);
      red = '0;
      green = '0;
      blue = '0;

      vertical_bin = (width_value == 0) ? 0 : int'((x_value * 64'd8) / width_value);
      horizontal_bin = (height_value == 0) ? 0 : int'((y_value * 64'd8) / height_value);
      if (vertical_bin > 7) begin
        vertical_bin = 7;
      end
      if (horizontal_bin > 7) begin
        horizontal_bin = 7;
      end

      checker_on = (((x_value >> 5) ^ (y_value >> 5)) & 64'd1) != 64'd0;
      grid_on = ((x_value & 64'd31) == 64'd0) || ((y_value & 64'd31) == 64'd0);

      unique case (pattern)
        PATTERN_W'(0): begin
          red = from_u8(8'h18);
          green = from_u8(8'h80);
          blue = from_u8(8'hf0);
        end
        PATTERN_W'(1): begin
          unique case (vertical_bin)
            0: begin red = from_u8(8'hff); green = from_u8(8'h00); blue = from_u8(8'h00); end
            1: begin red = from_u8(8'hff); green = from_u8(8'h80); blue = from_u8(8'h00); end
            2: begin red = from_u8(8'hff); green = from_u8(8'hff); blue = from_u8(8'h00); end
            3: begin red = from_u8(8'h00); green = from_u8(8'hff); blue = from_u8(8'h00); end
            4: begin red = from_u8(8'h00); green = from_u8(8'hff); blue = from_u8(8'hff); end
            5: begin red = from_u8(8'h00); green = from_u8(8'h80); blue = from_u8(8'hff); end
            6: begin red = from_u8(8'h40); green = from_u8(8'h00); blue = from_u8(8'hff); end
            default: begin red = from_u8(8'hff); green = from_u8(8'hff); blue = from_u8(8'hff); end
          endcase
        end
        PATTERN_W'(2): begin
          unique case (horizontal_bin)
            0: begin red = from_u8(8'h20); green = from_u8(8'h20); blue = from_u8(8'h20); end
            1: begin red = from_u8(8'h40); green = from_u8(8'h00); blue = from_u8(8'h80); end
            2: begin red = from_u8(8'h00); green = from_u8(8'h40); blue = from_u8(8'h80); end
            3: begin red = from_u8(8'h00); green = from_u8(8'h80); blue = from_u8(8'h40); end
            4: begin red = from_u8(8'h80); green = from_u8(8'h40); blue = from_u8(8'h00); end
            5: begin red = from_u8(8'h80); green = from_u8(8'h00); blue = from_u8(8'h40); end
            6: begin red = from_u8(8'hc0); green = from_u8(8'h80); blue = from_u8(8'h20); end
            default: begin red = from_u8(8'hff); green = from_u8(8'hff); blue = from_u8(8'hff); end
          endcase
        end
        PATTERN_W'(3): begin
          if (checker_on) begin
            red = from_u8(8'hee);
            green = from_u8(8'hee);
            blue = from_u8(8'hee);
          end else begin
            red = from_u8(8'h22);
            green = from_u8(8'h22);
            blue = from_u8(8'h22);
          end
        end
        PATTERN_W'(4): begin
          red = scale_to_channel(x_value, width_value);
          green = scale_to_channel(y_value, height_value);
          blue = scale_to_channel(x_value + y_value, width_value + height_value);
        end
        PATTERN_W'(5): begin
          if (grid_on) begin
            red = from_u8(8'hff);
            green = from_u8(8'hff);
            blue = from_u8(8'hff);
          end else begin
            red = scale_to_channel(x_value, width_value) >> 1;
            green = scale_to_channel(y_value, height_value) >> 1;
            blue = from_u8(8'h30);
          end
        end
        default: begin
          red = from_u8(8'hff);
          green = from_u8(8'h00);
          blue = from_u8(8'hff);
        end
      endcase

      return {red, green, blue};
    end
  endfunction

  task automatic drive_idle();
    rst_i = 1'b1;
    use_external_pixel_tick_i = 1'b0;
    external_pixel_tick_i = 1'b0;
    rate_enable_i = 1'b0;
    input_clk_hz_i = 32'd100000000;
    pixel_clk_hz_i = 32'd25175000;
    pattern_auto_advance_i = 1'b0;
    hold_last_pattern_i = 1'b0;
    frames_per_step_i = FRAMES_COUNTER_W'(1);
    last_pattern_i = PATTERN_W'(5);
    pattern_select_i = '0;
    solid_red_i = from_u8(8'h18);
    solid_green_i = from_u8(8'h80);
    solid_blue_i = from_u8(8'hf0);
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

  task automatic apply_scenario(input int unsigned scenario_idx);
    int unsigned mode_idx;
    video_mode_cfg_t current_mode;
    begin
      mode_idx = scenario_mode_index(scenario_idx);
      current_mode = get_mode_cfg(mode_idx);
      drive_idle();
      input_clk_hz_i = current_mode.rate_cfg.input_clk_hz;
      pixel_clk_hz_i = current_mode.rate_cfg.pixel_clk_hz;
      h_visible_i = COORD_W'(current_mode.timing_cfg.h_visible);
      h_front_i = COORD_W'(current_mode.timing_cfg.h_front);
      h_sync_i = COORD_W'(current_mode.timing_cfg.h_sync);
      h_back_i = COORD_W'(current_mode.timing_cfg.h_back);
      v_visible_i = COORD_W'(current_mode.timing_cfg.v_visible);
      v_front_i = COORD_W'(current_mode.timing_cfg.v_front);
      v_sync_i = COORD_W'(current_mode.timing_cfg.v_sync);
      v_back_i = COORD_W'(current_mode.timing_cfg.v_back);
      hsync_active_low_i = current_mode.timing_cfg.hsync_active_low;
      vsync_active_low_i = current_mode.timing_cfg.vsync_active_low;
      rate_enable_i = current_mode.rate_cfg.enable;

      unique case (scenario_idx)
        0: begin
          pattern_auto_advance_i = 1'b0;
          pattern_select_i = PATTERN_W'(0);
        end
        1: begin
          pattern_auto_advance_i = 1'b0;
          pattern_select_i = PATTERN_W'(1);
        end
        2: begin
          use_external_pixel_tick_i = 1'b1;
          external_pixel_tick_i = 1'b1;
          rate_enable_i = 1'b0;
          pattern_auto_advance_i = 1'b0;
          pattern_select_i = PATTERN_W'(4);
        end
        default: begin
          rate_enable_i = 1'b1;
          pattern_auto_advance_i = 1'b1;
          hold_last_pattern_i = 1'b1;
          pattern_select_i = PATTERN_W'(0);
        end
      endcase

      repeat (4) @(posedge clk);
  rst_i = 1'b0;
      @(posedge clk);
      $display("T=%0t [TB] Applied scenario %0d: %s", $time, scenario_idx,
               scenario_name(scenario_idx));
    end
  endtask

  task automatic check_frame(input int unsigned scenario_idx, input int unsigned frame_idx);
    int unsigned total_pixels;
    int unsigned visible_pixels;
    int unsigned visible_rgb_count;
    int unsigned line_pixels;
    int unsigned hsync_pixels;
    int unsigned line_count;
    int unsigned min_line_ticks;
    int unsigned max_line_ticks;
    int unsigned min_hsync_ticks;
    int unsigned max_hsync_ticks;
    int unsigned min_hsync_start_x;
    int unsigned max_hsync_start_x;
    int unsigned min_hsync_end_x;
    int unsigned max_hsync_end_x;
    int unsigned vsync_line_count;
    int unsigned min_vsync_line;
    int unsigned max_vsync_line;
    logic [PATTERN_W-1:0] expected_pattern_value;
    logic [(3*COLOR_W)-1:0] visible_rgb[];
    int unsigned sample_x[SAMPLE_COUNT];
    int unsigned sample_y[SAMPLE_COUNT];
    bit          sample_valid[SAMPLE_COUNT];
    logic [(3*COLOR_W)-1:0] sample_rgb[SAMPLE_COUNT];
    bit          frame_started;
    bit          frame_ended;
    bit          frame_pattern_captured;
    bit          hsync_active;
    bit          vsync_active;
    bit          line_hsync_seen;
    int unsigned h_total;
    int unsigned v_total;
    int unsigned h_visible;
    int unsigned v_visible;
    int unsigned expected_hsync_start_x;
    int unsigned expected_hsync_end_x;
    int unsigned expected_vsync_start_line;
    int unsigned expected_vsync_end_line;
    int unsigned visible_index;
    int unsigned line_hsync_start_x;
    int unsigned line_hsync_end_x;
    int unsigned line_y;
    int unsigned raster_index;
    int unsigned raster_mismatch_count;
    int unsigned first_bad_x;
    int unsigned first_bad_y;
    video_mode_cfg_t current_mode;
    logic [PATTERN_W-1:0] frame_pattern_value;
    logic [(3*COLOR_W)-1:0] expected_sample_rgb;
    logic [(3*COLOR_W)-1:0] first_bad_actual_rgb;
    logic [(3*COLOR_W)-1:0] first_bad_expected_rgb;
    begin
      total_pixels = 0;
      visible_pixels = 0;
      visible_rgb_count = 0;
      line_pixels = 0;
      hsync_pixels = 0;
      line_count = 0;
      min_line_ticks = 32'hffff_ffff;
      max_line_ticks = 0;
      min_hsync_ticks = 32'hffff_ffff;
      max_hsync_ticks = 0;
      min_hsync_start_x = 32'hffff_ffff;
      max_hsync_start_x = 0;
      min_hsync_end_x = 32'hffff_ffff;
      max_hsync_end_x = 0;
      vsync_line_count = 0;
      min_vsync_line = 32'hffff_ffff;
      max_vsync_line = 0;
      frame_started = 1'b0;
      frame_ended = 1'b0;
      frame_pattern_captured = 1'b0;
      line_hsync_seen = 1'b0;
      current_mode = get_mode_cfg(scenario_mode_index(scenario_idx));
      h_total = expected_h_total(scenario_idx);
      v_total = expected_v_total(scenario_idx);
      h_visible = int'(current_mode.timing_cfg.h_visible);
      v_visible = int'(current_mode.timing_cfg.v_visible);
      expected_hsync_start_x = h_visible + int'(current_mode.timing_cfg.h_front);
      expected_hsync_end_x = expected_hsync_start_x + int'(current_mode.timing_cfg.h_sync);
      expected_vsync_start_line = v_visible + int'(current_mode.timing_cfg.v_front);
      expected_vsync_end_line = expected_vsync_start_line + int'(current_mode.timing_cfg.v_sync);
      expected_pattern_value = expected_pattern(scenario_idx, frame_idx);
      visible_rgb_count = h_visible * v_visible;
      visible_rgb = new[visible_rgb_count];
      visible_index = 0;
      line_hsync_start_x = 0;
      line_hsync_end_x = 0;
      line_y = 0;
      raster_index = 0;
      raster_mismatch_count = 0;
      first_bad_x = 0;
      first_bad_y = 0;
      first_bad_actual_rgb = '0;
      first_bad_expected_rgb = '0;

      sample_x[0] = 0;
      sample_y[0] = 0;
      sample_x[1] = (h_visible > 1) ? 1 : 0;
      sample_y[1] = (v_visible > 1) ? 1 : 0;
      sample_x[2] = h_visible >> 1;
      sample_y[2] = 0;
      sample_x[3] = h_visible >> 1;
      sample_y[3] = v_visible >> 1;
      sample_x[4] = (h_visible == 0) ? 0 : (h_visible - 1);
      sample_y[4] = (v_visible == 0) ? 0 : (v_visible - 1);

      for (int sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx++) begin
        sample_valid[sample_idx] = 1'b0;
        sample_rgb[sample_idx] = '0;
      end

      while (!frame_ended) begin
        @(posedge clk);
        #1;

        if (rst_i || !pixel_tick_o) begin
          continue;
        end

        if (!frame_started) begin
          if (!frame_start_o) begin
            continue;
          end
          frame_started = 1'b1;
          frame_pattern_value = active_pattern_o;
          frame_pattern_captured = 1'b1;
        end

        if (stream_error_o || timing_error_o || rate_error_o) begin
          $fatal(1,
                 "T=%0t [TB] Scenario %0d frame %0d error flags stream=%0b timing=%0b rate=%0b",
                 $time, scenario_idx, frame_idx, stream_error_o, timing_error_o, rate_error_o);
        end

        hsync_active = hsync_active_low_i ? !hsync_o : hsync_o;
        vsync_active = vsync_active_low_i ? !vsync_o : vsync_o;

        if (hsync_active && !line_hsync_seen) begin
          line_hsync_seen = 1'b1;
          line_hsync_start_x = int'(x_o);
        end

        total_pixels++;
        if (visible_o) begin
          visible_index = visible_pixels;
          if (visible_index < visible_rgb_count) begin
            visible_rgb[visible_index] = {red_o, green_o, blue_o};
          end
          visible_pixels++;
          for (int sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx++) begin
            if (!sample_valid[sample_idx] && (int'(x_o) == sample_x[sample_idx])
                && (int'(y_o) == sample_y[sample_idx])) begin
              sample_rgb[sample_idx] = {red_o, green_o, blue_o};
              sample_valid[sample_idx] = 1'b1;
            end
          end
        end

        line_pixels++;
        if (hsync_active) begin
          hsync_pixels++;
        end

        if (int'(x_o) == (h_total - 1)) begin
          line_count++;
          line_y = int'(y_o);
          if (line_pixels < min_line_ticks) begin
            min_line_ticks = line_pixels;
          end
          if (line_pixels > max_line_ticks) begin
            max_line_ticks = line_pixels;
          end
          if (hsync_pixels < min_hsync_ticks) begin
            min_hsync_ticks = hsync_pixels;
          end
          if (hsync_pixels > max_hsync_ticks) begin
            max_hsync_ticks = hsync_pixels;
          end
          if (line_hsync_seen) begin
            line_hsync_end_x = line_hsync_start_x + hsync_pixels;
            if (line_hsync_start_x < min_hsync_start_x) begin
              min_hsync_start_x = line_hsync_start_x;
            end
            if (line_hsync_start_x > max_hsync_start_x) begin
              max_hsync_start_x = line_hsync_start_x;
            end
            if (line_hsync_end_x < min_hsync_end_x) begin
              min_hsync_end_x = line_hsync_end_x;
            end
            if (line_hsync_end_x > max_hsync_end_x) begin
              max_hsync_end_x = line_hsync_end_x;
            end
          end
          if (vsync_active) begin
            vsync_line_count++;
            if (line_y < min_vsync_line) begin
              min_vsync_line = line_y;
            end
            if (line_y > max_vsync_line) begin
              max_vsync_line = line_y;
            end
          end
          line_hsync_seen = 1'b0;
          line_hsync_start_x = 0;
          line_hsync_end_x = 0;
          line_pixels = 0;
          hsync_pixels = 0;
        end

        if (frame_end_o) begin
          frame_ended = 1'b1;
        end
      end

      if (!frame_started) begin
        $fatal(1, "T=%0t [TB] Scenario %0d frame %0d never started", $time, scenario_idx,
               frame_idx);
      end
      if (total_pixels != (h_total * v_total)) begin
        $fatal(1, "T=%0t [TB] total_pixels=%0d expected=%0d", $time, total_pixels,
               h_total * v_total);
      end
      if (visible_pixels != (h_visible * v_visible)) begin
        $fatal(1, "T=%0t [TB] visible_pixels=%0d expected=%0d", $time, visible_pixels,
               h_visible * v_visible);
      end
      if (line_count != v_total) begin
        $fatal(1, "T=%0t [TB] line_count=%0d expected=%0d", $time, line_count, v_total);
      end
      if ((min_line_ticks != h_total) || (max_line_ticks != h_total)) begin
        $fatal(1, "T=%0t [TB] line tick range=[%0d,%0d] expected=%0d", $time,
               min_line_ticks, max_line_ticks, h_total);
      end
      if ((min_hsync_ticks != int'(current_mode.timing_cfg.h_sync))
          || (max_hsync_ticks != int'(current_mode.timing_cfg.h_sync))) begin
        $fatal(1, "T=%0t [TB] hsync tick range=[%0d,%0d] expected=%0d", $time,
               min_hsync_ticks, max_hsync_ticks, int'(current_mode.timing_cfg.h_sync));
      end
      if (((min_hsync_start_x - h_visible) != int'(current_mode.timing_cfg.h_front))
          || ((max_hsync_start_x - h_visible) != int'(current_mode.timing_cfg.h_front))) begin
        $fatal(1, "T=%0t [TB] hfront porch range=[%0d,%0d] expected=%0d", $time,
               min_hsync_start_x - h_visible, max_hsync_start_x - h_visible,
               int'(current_mode.timing_cfg.h_front));
      end
      if (((h_total - max_hsync_end_x) != int'(current_mode.timing_cfg.h_back))
          || ((h_total - min_hsync_end_x) != int'(current_mode.timing_cfg.h_back))) begin
        $fatal(1, "T=%0t [TB] hback porch range=[%0d,%0d] expected=%0d", $time,
               h_total - max_hsync_end_x, h_total - min_hsync_end_x,
               int'(current_mode.timing_cfg.h_back));
      end
      if (vsync_line_count != int'(current_mode.timing_cfg.v_sync)) begin
        $fatal(1, "T=%0t [TB] vsync_line_count=%0d expected=%0d", $time, vsync_line_count,
               int'(current_mode.timing_cfg.v_sync));
      end
      if ((min_vsync_line != expected_vsync_start_line)
          || ((min_vsync_line - v_visible) != int'(current_mode.timing_cfg.v_front))) begin
        $fatal(1, "T=%0t [TB] vfront porch start=%0d porch=%0d expected_start=%0d expected=%0d",
               $time, min_vsync_line, min_vsync_line - v_visible, expected_vsync_start_line,
               int'(current_mode.timing_cfg.v_front));
      end
      if (((max_vsync_line + 1) != expected_vsync_end_line)
          || ((v_total - (max_vsync_line + 1)) != int'(current_mode.timing_cfg.v_back))) begin
        $fatal(1, "T=%0t [TB] vback porch end=%0d porch=%0d expected_end=%0d expected=%0d",
               $time, max_vsync_line + 1, v_total - (max_vsync_line + 1),
               expected_vsync_end_line, int'(current_mode.timing_cfg.v_back));
      end
      if (!frame_pattern_captured) begin
        $fatal(1, "T=%0t [TB] frame pattern was never captured", $time);
      end
      if (frame_pattern_value !== expected_pattern_value) begin
        $fatal(1, "T=%0t [TB] frame_pattern=%0d expected=%0d", $time, frame_pattern_value,
               expected_pattern_value);
      end

      raster_index = 0;
      for (int unsigned y_idx = 0; y_idx < v_visible; y_idx++) begin
        for (int unsigned x_idx = 0; x_idx < h_visible; x_idx++) begin
          expected_sample_rgb = expected_rgb(PATTERN_W'(expected_pattern_value), x_idx, y_idx,
                                             scenario_idx);
          if (visible_rgb[raster_index] !== expected_sample_rgb) begin
            if (raster_mismatch_count == 0) begin
              first_bad_x = x_idx;
              first_bad_y = y_idx;
              first_bad_actual_rgb = visible_rgb[raster_index];
              first_bad_expected_rgb = expected_sample_rgb;
            end
            raster_mismatch_count++;
          end
          raster_index++;
        end
      end

      if (raster_mismatch_count != 0) begin
        $fatal(1,
               "T=%0t [TB] raster mismatches=%0d first=(%0d,%0d) rgb=0x%0h expected=0x%0h",
               $time, raster_mismatch_count, first_bad_x, first_bad_y, first_bad_actual_rgb,
               first_bad_expected_rgb);
      end

      for (int sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx++) begin
        if (!sample_valid[sample_idx]) begin
          $fatal(1, "T=%0t [TB] missing sample %0d at (%0d,%0d)", $time, sample_idx,
                 sample_x[sample_idx], sample_y[sample_idx]);
        end
        expected_sample_rgb = expected_rgb(PATTERN_W'(expected_pattern_value),
                                           sample_x[sample_idx], sample_y[sample_idx],
                                           scenario_idx);
        if (sample_rgb[sample_idx] !== expected_sample_rgb) begin
          $fatal(1, "T=%0t [TB] sample %0d rgb=0x%0h expected=0x%0h", $time, sample_idx,
                 sample_rgb[sample_idx], expected_sample_rgb);
        end
      end

      pass_cnt++;
      $display("T=%0t [TB] PASS scenario=%0d frame=%0d name=%s", $time, scenario_idx,
               frame_idx, scenario_name(scenario_idx));
    end
  endtask

  initial begin
    pass_cnt = 0;
    drive_idle();
    repeat (5) @(posedge clk);

    for (int unsigned scenario_idx = 0; scenario_idx < 4; scenario_idx++) begin
      apply_scenario(scenario_idx);
      for (int unsigned frame_idx = 0; frame_idx < frames_to_check(scenario_idx); frame_idx++) begin
        check_frame(scenario_idx, frame_idx);
      end
    end

    $display("=== VERILATOR TB SUMMARY: PASS=%0d FAIL=0 ===", pass_cnt);
    repeat (20) @(posedge clk);
    $finish(1);
  end

  initial begin
    #1000000000 $fatal(1, "TIMEOUT: Verilator TB did not finish within the limit.");
  end
endmodule