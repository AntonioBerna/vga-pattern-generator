/**
 * @package video_pipeline_tb_pkg
 * @brief OOP testbench components for video_pipeline_top.
 *
 * The package contains reusable scenario generation, driver, monitor, and
 * scoreboard classes. It now reuses the RTL package configuration structs so
 * the testbench does not duplicate the timing and rate configuration schema.
 */
package video_pipeline_tb_pkg;
  localparam int COLOR_W = 8;
  localparam int COORD_W = 16;
  localparam int PATTERN_W = 3;
  localparam int FRAMES_COUNTER_W = 16;
  localparam int SAMPLE_COUNT = 5;

  typedef struct packed {
    video_types_pkg::video_rate_cfg_t   rate_cfg;
    video_types_pkg::video_timing_cfg_t timing_cfg;
  } video_mode_cfg_t;

  typedef enum int unsigned {
    SCN_SOLID_INTERNAL = 0,
    SCN_VERTICAL_INTERNAL = 1,
    SCN_GRADIENT_EXTERNAL = 2,
    SCN_AUTO_SEQUENCE_HOLD = 3
  } scenario_kind_e;

  function automatic video_mode_cfg_t make_mode(
      input logic [31:0]        input_clk_hz,
      input logic [31:0]        pixel_clk_hz,
      input logic [COORD_W-1:0] h_visible,
      input logic [COORD_W-1:0] h_front,
      input logic [COORD_W-1:0] h_sync,
      input logic [COORD_W-1:0] h_back,
      input logic [COORD_W-1:0] v_visible,
      input logic [COORD_W-1:0] v_front,
      input logic [COORD_W-1:0] v_sync,
      input logic [COORD_W-1:0] v_back,
      input logic               hsync_active_low,
      input logic               vsync_active_low
  );
    video_mode_cfg_t mode;
    begin
      mode.rate_cfg.enable = 1'b1;
      mode.rate_cfg.input_clk_hz = video_types_pkg::video_cfg_word_t'(input_clk_hz);
      mode.rate_cfg.pixel_clk_hz = video_types_pkg::video_cfg_word_t'(pixel_clk_hz);
      mode.timing_cfg.h_visible = video_types_pkg::video_cfg_word_t'(h_visible);
      mode.timing_cfg.h_front = video_types_pkg::video_cfg_word_t'(h_front);
      mode.timing_cfg.h_sync = video_types_pkg::video_cfg_word_t'(h_sync);
      mode.timing_cfg.h_back = video_types_pkg::video_cfg_word_t'(h_back);
      mode.timing_cfg.v_visible = video_types_pkg::video_cfg_word_t'(v_visible);
      mode.timing_cfg.v_front = video_types_pkg::video_cfg_word_t'(v_front);
      mode.timing_cfg.v_sync = video_types_pkg::video_cfg_word_t'(v_sync);
      mode.timing_cfg.v_back = video_types_pkg::video_cfg_word_t'(v_back);
      mode.timing_cfg.hsync_active_low = hsync_active_low;
      mode.timing_cfg.vsync_active_low = vsync_active_low;
      return mode;
    end
  endfunction

  function automatic int unsigned cfg_word_to_uint(input video_types_pkg::video_cfg_word_t value);
    return int'(value);
  endfunction

  function automatic video_mode_cfg_t get_mode_cfg(input int unsigned index);
    begin
      unique case (index)
        0: begin
          return make_mode(32'd100000000, 32'd25175000, 16'd640, 16'd16, 16'd96, 16'd48,
                           16'd480, 16'd10, 16'd2, 16'd33, 1'b1, 1'b1);
        end
        1: begin
          return make_mode(32'd100000000, 32'd40000000, 16'd800, 16'd40, 16'd128, 16'd88,
                           16'd600, 16'd1, 16'd4, 16'd23, 1'b0, 1'b0);
        end
        default: begin
          return make_mode(32'd100000000, 32'd65000000, 16'd1024, 16'd24, 16'd136, 16'd160,
                           16'd768, 16'd3, 16'd6, 16'd29, 1'b1, 1'b1);
        end
      endcase
    end
  endfunction

  function automatic string get_mode_name(input int unsigned index);
    begin
      unique case (index)
        0: return "640x480@60";
        1: return "800x600@60";
        default: return "1024x768@60";
      endcase
    end
  endfunction

  function automatic int unsigned h_total_for_mode(input video_mode_cfg_t mode);
    return cfg_word_to_uint(mode.timing_cfg.h_visible) + cfg_word_to_uint(mode.timing_cfg.h_front)
         + cfg_word_to_uint(mode.timing_cfg.h_sync) + cfg_word_to_uint(mode.timing_cfg.h_back);
  endfunction

  function automatic int unsigned v_total_for_mode(input video_mode_cfg_t mode);
    return cfg_word_to_uint(mode.timing_cfg.v_visible) + cfg_word_to_uint(mode.timing_cfg.v_front)
         + cfg_word_to_uint(mode.timing_cfg.v_sync) + cfg_word_to_uint(mode.timing_cfg.v_back);
  endfunction

  function automatic int unsigned hsync_start_for_mode(input video_mode_cfg_t mode);
    return cfg_word_to_uint(mode.timing_cfg.h_visible) + cfg_word_to_uint(mode.timing_cfg.h_front);
  endfunction

  function automatic int unsigned hsync_end_for_mode(input video_mode_cfg_t mode);
    return hsync_start_for_mode(mode) + cfg_word_to_uint(mode.timing_cfg.h_sync);
  endfunction

  function automatic int unsigned vsync_start_for_mode(input video_mode_cfg_t mode);
    return cfg_word_to_uint(mode.timing_cfg.v_visible) + cfg_word_to_uint(mode.timing_cfg.v_front);
  endfunction

  function automatic int unsigned vsync_end_for_mode(input video_mode_cfg_t mode);
    return vsync_start_for_mode(mode) + cfg_word_to_uint(mode.timing_cfg.v_sync);
  endfunction

  function automatic logic [COLOR_W-1:0] from_u8(input logic [7:0] value);
    return COLOR_W'(((64'(value) * (((64'd1 << COLOR_W) - 1))) + 64'd127) / 64'd255);
  endfunction

  function automatic logic [COLOR_W-1:0] scale_to_channel(
      input longint unsigned value,
      input longint unsigned span
  );
    if (span <= 1) begin
      return '0;
    end

    return COLOR_W'((value * (((64'd1 << COLOR_W) - 1))) / (span - 1));
  endfunction

  function automatic logic [(3*COLOR_W)-1:0] expected_pixel(
      input logic [PATTERN_W-1:0] pattern_select,
      input logic [COORD_W-1:0]   x,
      input logic [COORD_W-1:0]   y,
      input video_mode_cfg_t      mode,
      input logic [COLOR_W-1:0]   solid_red,
      input logic [COLOR_W-1:0]   solid_green,
      input logic [COLOR_W-1:0]   solid_blue
  );
    logic [COLOR_W-1:0] red;
    logic [COLOR_W-1:0] green;
    logic [COLOR_W-1:0] blue;
    longint unsigned    x_value;
    longint unsigned    y_value;
    longint unsigned    width_value;
    longint unsigned    height_value;
    int unsigned        vertical_bin;
    int unsigned        horizontal_bin;
    bit                 checker_on;
    bit                 grid_on;
    begin
      red = '0;
      green = '0;
      blue = '0;
      x_value = x;
      y_value = y;
      width_value = mode.timing_cfg.h_visible;
      height_value = mode.timing_cfg.v_visible;

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

      unique case (pattern_select)
        PATTERN_W'(0): begin
          red = solid_red;
          green = solid_green;
          blue = solid_blue;
        end
        PATTERN_W'(1): begin
          unique case (vertical_bin)
            0: begin
              red = from_u8(8'hff);
              green = from_u8(8'h00);
              blue = from_u8(8'h00);
            end
            1: begin
              red = from_u8(8'hff);
              green = from_u8(8'h80);
              blue = from_u8(8'h00);
            end
            2: begin
              red = from_u8(8'hff);
              green = from_u8(8'hff);
              blue = from_u8(8'h00);
            end
            3: begin
              red = from_u8(8'h00);
              green = from_u8(8'hff);
              blue = from_u8(8'h00);
            end
            4: begin
              red = from_u8(8'h00);
              green = from_u8(8'hff);
              blue = from_u8(8'hff);
            end
            5: begin
              red = from_u8(8'h00);
              green = from_u8(8'h80);
              blue = from_u8(8'hff);
            end
            6: begin
              red = from_u8(8'h40);
              green = from_u8(8'h00);
              blue = from_u8(8'hff);
            end
            default: begin
              red = from_u8(8'hff);
              green = from_u8(8'hff);
              blue = from_u8(8'hff);
            end
          endcase
        end
        PATTERN_W'(2): begin
          unique case (horizontal_bin)
            0: begin
              red = from_u8(8'h20);
              green = from_u8(8'h20);
              blue = from_u8(8'h20);
            end
            1: begin
              red = from_u8(8'h40);
              green = from_u8(8'h00);
              blue = from_u8(8'h80);
            end
            2: begin
              red = from_u8(8'h00);
              green = from_u8(8'h40);
              blue = from_u8(8'h80);
            end
            3: begin
              red = from_u8(8'h00);
              green = from_u8(8'h80);
              blue = from_u8(8'h40);
            end
            4: begin
              red = from_u8(8'h80);
              green = from_u8(8'h40);
              blue = from_u8(8'h00);
            end
            5: begin
              red = from_u8(8'h80);
              green = from_u8(8'h00);
              blue = from_u8(8'h40);
            end
            6: begin
              red = from_u8(8'hc0);
              green = from_u8(8'h80);
              blue = from_u8(8'h20);
            end
            default: begin
              red = from_u8(8'hff);
              green = from_u8(8'hff);
              blue = from_u8(8'hff);
            end
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

  class video_transaction;
    rand scenario_kind_e            scenario_kind;
    rand logic [COLOR_W-1:0]        solid_red;
    rand logic [COLOR_W-1:0]        solid_green;
    rand logic [COLOR_W-1:0]        solid_blue;

    int unsigned                    transaction_id;
    string                          label;
    video_mode_cfg_t                mode;
    bit                             use_external_pixel_tick;
    bit                             pattern_auto_advance;
    bit                             hold_last_pattern;
    logic [FRAMES_COUNTER_W-1:0]    frames_per_step;
    logic [PATTERN_W-1:0]           last_pattern;
    logic [PATTERN_W-1:0]           pattern_select;
    int unsigned                    frames_to_check;

    constraint c_solid_non_zero {
      if (scenario_kind == SCN_SOLID_INTERNAL) {
        (solid_red != '0) || (solid_green != '0) || (solid_blue != '0);
      }
    }

    function void apply_scenario_defaults();
      unique case (scenario_kind)
        SCN_SOLID_INTERNAL: begin
          mode = get_mode_cfg(0);
          label = "manual solid color with internal rate generator";
          use_external_pixel_tick = 1'b0;
          pattern_auto_advance = 1'b0;
          hold_last_pattern = 1'b0;
          frames_per_step = FRAMES_COUNTER_W'(1);
          last_pattern = PATTERN_W'(5);
          pattern_select = PATTERN_W'(0);
          frames_to_check = 2;
          if ((solid_red == '0) && (solid_green == '0) && (solid_blue == '0)) begin
            solid_red = from_u8(8'h18);
            solid_green = from_u8(8'h80);
            solid_blue = from_u8(8'hf0);
          end
        end
        SCN_VERTICAL_INTERNAL: begin
          mode = get_mode_cfg(1);
          label = "manual vertical bars with internal rate generator";
          use_external_pixel_tick = 1'b0;
          pattern_auto_advance = 1'b0;
          hold_last_pattern = 1'b0;
          frames_per_step = FRAMES_COUNTER_W'(1);
          last_pattern = PATTERN_W'(5);
          pattern_select = PATTERN_W'(1);
          frames_to_check = 1;
          solid_red = from_u8(8'h18);
          solid_green = from_u8(8'h80);
          solid_blue = from_u8(8'hf0);
        end
        SCN_GRADIENT_EXTERNAL: begin
          mode = get_mode_cfg(2);
          mode.rate_cfg.enable = 1'b0;
          label = "manual gradient with external pixel tick";
          use_external_pixel_tick = 1'b1;
          pattern_auto_advance = 1'b0;
          hold_last_pattern = 1'b0;
          frames_per_step = FRAMES_COUNTER_W'(1);
          last_pattern = PATTERN_W'(5);
          pattern_select = PATTERN_W'(4);
          frames_to_check = 1;
          solid_red = from_u8(8'h18);
          solid_green = from_u8(8'h80);
          solid_blue = from_u8(8'hf0);
        end
        default: begin
          mode = get_mode_cfg(0);
          label = "auto sequence with hold-last behavior";
          use_external_pixel_tick = 1'b0;
          pattern_auto_advance = 1'b1;
          hold_last_pattern = 1'b1;
          frames_per_step = FRAMES_COUNTER_W'(1);
          last_pattern = PATTERN_W'(5);
          pattern_select = PATTERN_W'(0);
          frames_to_check = 7;
          solid_red = from_u8(8'h18);
          solid_green = from_u8(8'h80);
          solid_blue = from_u8(8'hf0);
        end
      endcase
    endfunction

    function void post_randomize();
      apply_scenario_defaults();
    endfunction

    function video_transaction copy();
      video_transaction clone;
      clone = new();
      clone.transaction_id = transaction_id;
      clone.scenario_kind = scenario_kind;
      clone.label = label;
      clone.mode = mode;
      clone.use_external_pixel_tick = use_external_pixel_tick;
      clone.pattern_auto_advance = pattern_auto_advance;
      clone.hold_last_pattern = hold_last_pattern;
      clone.frames_per_step = frames_per_step;
      clone.last_pattern = last_pattern;
      clone.pattern_select = pattern_select;
      clone.frames_to_check = frames_to_check;
      clone.solid_red = solid_red;
      clone.solid_green = solid_green;
      clone.solid_blue = solid_blue;
      return clone;
    endfunction

    function void print(string tag = "");
      $display(
          "T=%0t [%s] id=%0d kind=%0d mode=%s auto=%0b pattern=%0d frames=%0d ext_tick=%0b",
          $time, tag, transaction_id, scenario_kind, get_mode_name((scenario_kind == SCN_VERTICAL_INTERNAL)
              ? 1 : ((scenario_kind == SCN_GRADIENT_EXTERNAL) ? 2 : 0)), pattern_auto_advance,
          pattern_select, frames_to_check, use_external_pixel_tick);
    endfunction
  endclass

  class video_frame_observation;
    int unsigned                    total_pixel_ticks;
    int unsigned                    visible_pixel_ticks;
    int unsigned                    line_count;
    int unsigned                    min_line_ticks;
    int unsigned                    max_line_ticks;
    int unsigned                    min_hsync_ticks;
    int unsigned                    max_hsync_ticks;
    int unsigned                    min_hsync_start_x;
    int unsigned                    max_hsync_start_x;
    int unsigned                    min_hsync_end_x;
    int unsigned                    max_hsync_end_x;
    int unsigned                    vsync_line_count;
    int unsigned                    min_vsync_line;
    int unsigned                    max_vsync_line;
    bit                             frame_start_seen;
    bit                             frame_end_seen;
    bit                             stream_error_seen;
    bit                             timing_error_seen;
    bit                             rate_error_seen;
    logic [PATTERN_W-1:0]           active_pattern;
    int unsigned                    visible_rgb_count;
    logic [(3*COLOR_W)-1:0]         visible_rgb[];
    logic [COORD_W-1:0]             sample_x[SAMPLE_COUNT];
    logic [COORD_W-1:0]             sample_y[SAMPLE_COUNT];
    logic [(3*COLOR_W)-1:0]         sample_rgb[SAMPLE_COUNT];
    bit                             sample_valid[SAMPLE_COUNT];

    function new();
      total_pixel_ticks = 0;
      visible_pixel_ticks = 0;
      line_count = 0;
      min_line_ticks = '1;
      max_line_ticks = 0;
      min_hsync_ticks = '1;
      max_hsync_ticks = 0;
      min_hsync_start_x = '1;
      max_hsync_start_x = 0;
      min_hsync_end_x = '1;
      max_hsync_end_x = 0;
      vsync_line_count = 0;
      min_vsync_line = '1;
      max_vsync_line = 0;
      frame_start_seen = 1'b0;
      frame_end_seen = 1'b0;
      stream_error_seen = 1'b0;
      timing_error_seen = 1'b0;
      rate_error_seen = 1'b0;
      active_pattern = '0;
      visible_rgb_count = 0;
      visible_rgb = new[0];
      for (int i = 0; i < SAMPLE_COUNT; i++) begin
        sample_x[i] = '0;
        sample_y[i] = '0;
        sample_rgb[i] = '0;
        sample_valid[i] = 1'b0;
      end
    endfunction

    function void print(string tag = "");
      $display(
          "T=%0t [%s] frame_pixels=%0d visible_pixels=%0d lines=%0d hsync[min,max]=[%0d,%0d] pattern=%0d err=%0b/%0b/%0b",
          $time, tag, total_pixel_ticks, visible_pixel_ticks, line_count, min_hsync_ticks,
          max_hsync_ticks, active_pattern, stream_error_seen, timing_error_seen, rate_error_seen);
    endfunction
  endclass

  class generator;
    int                           num = 4;
    mailbox #(video_transaction)  drv_mbx;
    event                         drv_done;

    task run();
      scenario_kind_e scenario_order[4];
      int unsigned    scenario_count;
      scenario_order = '{SCN_SOLID_INTERNAL, SCN_VERTICAL_INTERNAL, SCN_GRADIENT_EXTERNAL,
                         SCN_AUTO_SEQUENCE_HOLD};
      scenario_count = $size(scenario_order);

      for (int i = 0; i < num; i++) begin
        video_transaction item;
        item = new();
        if (!item.randomize() with { scenario_kind == scenario_order[i % scenario_count]; }) begin
          $fatal(1, "T=%0t [Generator] Randomization failed for scenario %0d", $time, i);
        end
        item.transaction_id = i;
        item.print("Generator");
        drv_mbx.put(item);
        @(drv_done);
      end

      $display("T=%0t [Generator] Done", $time);
    endtask
  endclass

  class driver;
    virtual video_pipeline_if #(COLOR_W, COORD_W, PATTERN_W, FRAMES_COUNTER_W) vif;
    mailbox #(video_transaction)                                          drv_mbx;
    mailbox #(video_transaction)                                          cfg_mbx;
    event                                                                 drv_done;
    event                                                                 scb_done;

    task automatic apply_transaction(video_transaction item);
      @vif.drv_cb;
      vif.drv_cb.use_external_pixel_tick_i <= item.use_external_pixel_tick;
      vif.drv_cb.external_pixel_tick_i <= item.use_external_pixel_tick;
      vif.drive_rate_cfg_cb(item.mode.rate_cfg);
      vif.drv_cb.pattern_auto_advance_i <= item.pattern_auto_advance;
      vif.drv_cb.hold_last_pattern_i <= item.hold_last_pattern;
      vif.drv_cb.frames_per_step_i <= item.frames_per_step;
      vif.drv_cb.last_pattern_i <= item.last_pattern;
      vif.drv_cb.pattern_select_i <= item.pattern_select;
      vif.drv_cb.solid_red_i <= item.solid_red;
      vif.drv_cb.solid_green_i <= item.solid_green;
      vif.drv_cb.solid_blue_i <= item.solid_blue;
      vif.drive_timing_cfg_cb(item.mode.timing_cfg);
      vif.drv_cb.rst_i <= 1'b1;

      repeat (4) @vif.drv_cb;
      vif.drv_cb.rst_i <= 1'b0;
      @vif.drv_cb;
    endtask

    task run();
      $display("T=%0t [Driver] Starting", $time);
      if (vif == null) begin
        $fatal(1, "T=%0t [Driver] virtual interface not assigned", $time);
      end
      forever begin
        video_transaction item;
        drv_mbx.get(item);
        item.print("Driver");
        apply_transaction(item);
        cfg_mbx.put(item.copy());
        @(scb_done);
        ->drv_done;
      end
    endtask
  endclass

  class monitor;
    virtual video_pipeline_if #(COLOR_W, COORD_W, PATTERN_W, FRAMES_COUNTER_W) vif;
    mailbox #(video_frame_observation)                                        scb_mbx;

    function automatic int unsigned current_h_total();
      return int'(vif.mon_cb.h_visible_i) + int'(vif.mon_cb.h_front_i) + int'(vif.mon_cb.h_sync_i)
           + int'(vif.mon_cb.h_back_i);
    endfunction

    task automatic setup_samples(video_frame_observation frame_obs);
      logic [COORD_W-1:0] h_last;
      logic [COORD_W-1:0] v_last;
      int unsigned        visible_count;
      begin
        h_last = (vif.mon_cb.h_visible_i == '0) ? '0 : (vif.mon_cb.h_visible_i - 1'b1);
        v_last = (vif.mon_cb.v_visible_i == '0) ? '0 : (vif.mon_cb.v_visible_i - 1'b1);
        visible_count = int'(vif.mon_cb.h_visible_i) * int'(vif.mon_cb.v_visible_i);

        frame_obs.visible_rgb_count = visible_count;
        frame_obs.visible_rgb = new[visible_count];

        frame_obs.sample_x[0] = '0;
        frame_obs.sample_y[0] = '0;

        frame_obs.sample_x[1] = (vif.mon_cb.h_visible_i > 1) ? COORD_W'(1) : '0;
        frame_obs.sample_y[1] = (vif.mon_cb.v_visible_i > 1) ? COORD_W'(1) : '0;

        frame_obs.sample_x[2] = vif.mon_cb.h_visible_i >> 1;
        frame_obs.sample_y[2] = '0;

        frame_obs.sample_x[3] = vif.mon_cb.h_visible_i >> 1;
        frame_obs.sample_y[3] = vif.mon_cb.v_visible_i >> 1;

        frame_obs.sample_x[4] = h_last;
        frame_obs.sample_y[4] = v_last;
      end
    endtask

    task run();
      video_frame_observation frame_obs;
      int unsigned            line_pixels;
      int unsigned            hsync_pixels;
      int unsigned            line_hsync_start_x;
      int unsigned            line_hsync_end_x;
      int unsigned            line_y;
      int unsigned            visible_index;
      bit                     hsync_active;
      bit                     vsync_active;
      bit                     line_hsync_seen;

      $display("T=%0t [Monitor] Starting", $time);
      if (vif == null) begin
        $fatal(1, "T=%0t [Monitor] virtual interface not assigned", $time);
      end
      frame_obs = null;
      line_pixels = 0;
      hsync_pixels = 0;
      line_hsync_start_x = 0;
      line_hsync_end_x = 0;
      line_y = 0;
      visible_index = 0;
      line_hsync_seen = 1'b0;

      forever begin
        @(posedge vif.clk);
        #1;

        if (vif.mon_cb.rst_i) begin
          frame_obs = null;
          line_pixels = 0;
          hsync_pixels = 0;
          line_hsync_start_x = 0;
          line_hsync_end_x = 0;
          line_y = 0;
          visible_index = 0;
          line_hsync_seen = 1'b0;
          continue;
        end

        if (!vif.mon_cb.pixel_tick_o) begin
          continue;
        end

        if (vif.mon_cb.frame_start_o || (frame_obs == null)) begin
          frame_obs = new();
          setup_samples(frame_obs);
          frame_obs.frame_start_seen = vif.mon_cb.frame_start_o;
          frame_obs.active_pattern = vif.mon_cb.active_pattern_o;
          line_pixels = 0;
          hsync_pixels = 0;
          line_hsync_start_x = 0;
          line_hsync_end_x = 0;
          line_y = 0;
          visible_index = 0;
          line_hsync_seen = 1'b0;
        end

        hsync_active = vif.mon_cb.hsync_active_low_i ? !vif.mon_cb.hsync_o : vif.mon_cb.hsync_o;
        vsync_active = vif.mon_cb.vsync_active_low_i ? !vif.mon_cb.vsync_o : vif.mon_cb.vsync_o;

        if (hsync_active && !line_hsync_seen) begin
          line_hsync_seen = 1'b1;
          line_hsync_start_x = int'(vif.mon_cb.x_o);
        end

        frame_obs.total_pixel_ticks++;
        frame_obs.stream_error_seen |= vif.mon_cb.stream_error_o;
        frame_obs.timing_error_seen |= vif.mon_cb.timing_error_o;
        frame_obs.rate_error_seen |= vif.mon_cb.rate_error_o;

        if (vif.mon_cb.visible_o) begin
          visible_index = frame_obs.visible_pixel_ticks;
          if (visible_index < frame_obs.visible_rgb_count) begin
            frame_obs.visible_rgb[visible_index] = {vif.mon_cb.red_o, vif.mon_cb.green_o,
                                                    vif.mon_cb.blue_o};
          end
          frame_obs.visible_pixel_ticks++;
          for (int sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx++) begin
            if (!frame_obs.sample_valid[sample_idx]
                && (vif.mon_cb.x_o == frame_obs.sample_x[sample_idx])
                && (vif.mon_cb.y_o == frame_obs.sample_y[sample_idx])) begin
              frame_obs.sample_rgb[sample_idx] = {vif.mon_cb.red_o, vif.mon_cb.green_o,
                                                  vif.mon_cb.blue_o};
              frame_obs.sample_valid[sample_idx] = 1'b1;
            end
          end
        end

        line_pixels++;
        if (hsync_active) begin
          hsync_pixels++;
        end

        if (vif.mon_cb.x_o == COORD_W'(current_h_total() - 1)) begin
          frame_obs.line_count++;
          line_y = int'(vif.mon_cb.y_o);

          if (line_pixels < frame_obs.min_line_ticks) begin
            frame_obs.min_line_ticks = line_pixels;
          end
          if (line_pixels > frame_obs.max_line_ticks) begin
            frame_obs.max_line_ticks = line_pixels;
          end
          if (hsync_pixels < frame_obs.min_hsync_ticks) begin
            frame_obs.min_hsync_ticks = hsync_pixels;
          end
          if (hsync_pixels > frame_obs.max_hsync_ticks) begin
            frame_obs.max_hsync_ticks = hsync_pixels;
          end
          if (line_hsync_seen) begin
            line_hsync_end_x = line_hsync_start_x + hsync_pixels;
            if (line_hsync_start_x < frame_obs.min_hsync_start_x) begin
              frame_obs.min_hsync_start_x = line_hsync_start_x;
            end
            if (line_hsync_start_x > frame_obs.max_hsync_start_x) begin
              frame_obs.max_hsync_start_x = line_hsync_start_x;
            end
            if (line_hsync_end_x < frame_obs.min_hsync_end_x) begin
              frame_obs.min_hsync_end_x = line_hsync_end_x;
            end
            if (line_hsync_end_x > frame_obs.max_hsync_end_x) begin
              frame_obs.max_hsync_end_x = line_hsync_end_x;
            end
          end
          if (vsync_active) begin
            frame_obs.vsync_line_count++;
            if (line_y < frame_obs.min_vsync_line) begin
              frame_obs.min_vsync_line = line_y;
            end
            if (line_y > frame_obs.max_vsync_line) begin
              frame_obs.max_vsync_line = line_y;
            end
          end

          line_pixels = 0;
          hsync_pixels = 0;
          line_hsync_seen = 1'b0;
          line_hsync_start_x = 0;
          line_hsync_end_x = 0;
        end

        if (vif.mon_cb.frame_end_o) begin
          frame_obs.frame_end_seen = 1'b1;
          frame_obs.print("Monitor");
          scb_mbx.put(frame_obs);
          frame_obs = null;
          line_pixels = 0;
          hsync_pixels = 0;
          line_hsync_seen = 1'b0;
          line_hsync_start_x = 0;
          line_hsync_end_x = 0;
        end
      end
    endtask
  endclass

  class scoreboard;
    mailbox #(video_transaction)       cfg_mbx;
    mailbox #(video_frame_observation) scb_mbx;
    event                              scb_done;
    int                                pass_cnt = 0;
    int                                fail_cnt = 0;

    function automatic logic [PATTERN_W-1:0] expected_pattern_for_frame(
        input video_transaction cfg,
        input int unsigned      frame_idx
    );
      logic [PATTERN_W-1:0] pattern;
      int unsigned           frames_per_step;
      int unsigned           advances;
      begin
        if (!cfg.pattern_auto_advance) begin
          return cfg.pattern_select;
        end

        frames_per_step = (cfg.frames_per_step == '0) ? 1 : cfg.frames_per_step;
        advances = frame_idx / frames_per_step;
        pattern = '0;

        for (int unsigned step = 0; step < advances; step++) begin
          if (pattern != cfg.last_pattern) begin
            pattern = pattern + 1'b1;
          end else if (!cfg.hold_last_pattern) begin
            pattern = '0;
          end
        end

        return pattern;
      end
    endfunction

    function automatic bit check_frame(
        input video_transaction       cfg,
        input int unsigned            frame_idx,
        input video_frame_observation frame_obs
    );
      bit                     frame_ok;
      int unsigned            expected_h_total;
      int unsigned            expected_v_total;
      int unsigned            expected_visible_pixels;
      int unsigned            expected_h_front;
      int unsigned            expected_h_back;
      int unsigned            expected_v_front;
      int unsigned            expected_v_back;
      int unsigned            expected_hsync_start;
      int unsigned            expected_hsync_end;
      int unsigned            expected_vsync_start;
      int unsigned            expected_vsync_end;
      int unsigned            observed_h_front_min;
      int unsigned            observed_h_front_max;
      int unsigned            observed_h_back_min;
      int unsigned            observed_h_back_max;
      int unsigned            observed_v_front;
      int unsigned            observed_v_back;
      int unsigned            raster_index;
      int unsigned            raster_mismatch_count;
      int unsigned            first_bad_x;
      int unsigned            first_bad_y;
      logic [PATTERN_W-1:0]   expected_pattern;
      logic [(3*COLOR_W)-1:0] expected_rgb;
      logic [(3*COLOR_W)-1:0] first_bad_actual_rgb;
      logic [(3*COLOR_W)-1:0] first_bad_expected_rgb;
      begin
        frame_ok = 1'b1;
        expected_h_total = h_total_for_mode(cfg.mode);
        expected_v_total = v_total_for_mode(cfg.mode);
        expected_visible_pixels = cfg_word_to_uint(cfg.mode.timing_cfg.h_visible)
              * cfg_word_to_uint(cfg.mode.timing_cfg.v_visible);
        expected_h_front = cfg_word_to_uint(cfg.mode.timing_cfg.h_front);
        expected_h_back = cfg_word_to_uint(cfg.mode.timing_cfg.h_back);
        expected_v_front = cfg_word_to_uint(cfg.mode.timing_cfg.v_front);
        expected_v_back = cfg_word_to_uint(cfg.mode.timing_cfg.v_back);
        expected_hsync_start = hsync_start_for_mode(cfg.mode);
        expected_hsync_end = hsync_end_for_mode(cfg.mode);
        expected_vsync_start = vsync_start_for_mode(cfg.mode);
        expected_vsync_end = vsync_end_for_mode(cfg.mode);
        expected_pattern = expected_pattern_for_frame(cfg, frame_idx);

        if (frame_obs.total_pixel_ticks != (expected_h_total * expected_v_total)) begin
          $error("T=%0t [Scoreboard] FAIL total_pixel_ticks=%0d expected=%0d", $time,
                 frame_obs.total_pixel_ticks, expected_h_total * expected_v_total);
          frame_ok = 1'b0;
        end
        if (frame_obs.visible_pixel_ticks != expected_visible_pixels) begin
          $error("T=%0t [Scoreboard] FAIL visible_pixel_ticks=%0d expected=%0d", $time,
                 frame_obs.visible_pixel_ticks, expected_visible_pixels);
          frame_ok = 1'b0;
        end
        if (frame_obs.line_count != expected_v_total) begin
          $error("T=%0t [Scoreboard] FAIL line_count=%0d expected=%0d", $time,
                 frame_obs.line_count, expected_v_total);
          frame_ok = 1'b0;
        end
        if ((frame_obs.min_line_ticks != expected_h_total)
            || (frame_obs.max_line_ticks != expected_h_total)) begin
          $error("T=%0t [Scoreboard] FAIL line width range=[%0d,%0d] expected=%0d", $time,
                 frame_obs.min_line_ticks, frame_obs.max_line_ticks, expected_h_total);
          frame_ok = 1'b0;
        end
        if ((frame_obs.min_hsync_ticks != cfg_word_to_uint(cfg.mode.timing_cfg.h_sync))
            || (frame_obs.max_hsync_ticks != cfg_word_to_uint(cfg.mode.timing_cfg.h_sync))) begin
          $error("T=%0t [Scoreboard] FAIL hsync width range=[%0d,%0d] expected=%0d", $time,
                 frame_obs.min_hsync_ticks, frame_obs.max_hsync_ticks,
                 cfg_word_to_uint(cfg.mode.timing_cfg.h_sync));
          frame_ok = 1'b0;
        end
        observed_h_front_min = frame_obs.min_hsync_start_x - cfg_word_to_uint(cfg.mode.timing_cfg.h_visible);
        observed_h_front_max = frame_obs.max_hsync_start_x - cfg_word_to_uint(cfg.mode.timing_cfg.h_visible);
        if ((observed_h_front_min != expected_h_front) || (observed_h_front_max != expected_h_front)) begin
          $error("T=%0t [Scoreboard] FAIL hfront porch range=[%0d,%0d] expected=%0d",
                 $time, observed_h_front_min, observed_h_front_max, expected_h_front);
          frame_ok = 1'b0;
        end
        observed_h_back_min = expected_h_total - frame_obs.max_hsync_end_x;
        observed_h_back_max = expected_h_total - frame_obs.min_hsync_end_x;
        if ((observed_h_back_min != expected_h_back) || (observed_h_back_max != expected_h_back)) begin
          $error("T=%0t [Scoreboard] FAIL hback porch range=[%0d,%0d] expected=%0d",
                 $time, observed_h_back_min, observed_h_back_max, expected_h_back);
          frame_ok = 1'b0;
        end
        if (frame_obs.vsync_line_count != cfg_word_to_uint(cfg.mode.timing_cfg.v_sync)) begin
          $error("T=%0t [Scoreboard] FAIL vsync_line_count=%0d expected=%0d", $time,
                 frame_obs.vsync_line_count, cfg_word_to_uint(cfg.mode.timing_cfg.v_sync));
          frame_ok = 1'b0;
        end
        observed_v_front = frame_obs.min_vsync_line - cfg_word_to_uint(cfg.mode.timing_cfg.v_visible);
        if ((observed_v_front != expected_v_front) || (frame_obs.min_vsync_line != expected_vsync_start)) begin
          $error("T=%0t [Scoreboard] FAIL vfront porch start=%0d porch=%0d expected_start=%0d expected=%0d",
                 $time, frame_obs.min_vsync_line, observed_v_front, expected_vsync_start,
                 expected_v_front);
          frame_ok = 1'b0;
        end
        observed_v_back = expected_v_total - (frame_obs.max_vsync_line + 1);
        if ((observed_v_back != expected_v_back) || ((frame_obs.max_vsync_line + 1) != expected_vsync_end)) begin
          $error("T=%0t [Scoreboard] FAIL vback porch end=%0d porch=%0d expected_end=%0d expected=%0d",
                 $time, frame_obs.max_vsync_line + 1, observed_v_back, expected_vsync_end,
                 expected_v_back);
          frame_ok = 1'b0;
        end
        if (!frame_obs.frame_start_seen || !frame_obs.frame_end_seen) begin
          $error("T=%0t [Scoreboard] FAIL frame markers start=%0b end=%0b", $time,
                 frame_obs.frame_start_seen, frame_obs.frame_end_seen);
          frame_ok = 1'b0;
        end
        if (frame_obs.stream_error_seen || frame_obs.timing_error_seen || frame_obs.rate_error_seen) begin
          $error("T=%0t [Scoreboard] FAIL error flags stream=%0b timing=%0b rate=%0b", $time,
                 frame_obs.stream_error_seen, frame_obs.timing_error_seen, frame_obs.rate_error_seen);
          frame_ok = 1'b0;
        end
        if (frame_obs.active_pattern !== expected_pattern) begin
          $error("T=%0t [Scoreboard] FAIL active_pattern=%0d expected=%0d", $time,
                 frame_obs.active_pattern, expected_pattern);
          frame_ok = 1'b0;
        end

        if (frame_obs.visible_rgb_count != expected_visible_pixels) begin
          $error("T=%0t [Scoreboard] FAIL visible capture size=%0d expected=%0d", $time,
                 frame_obs.visible_rgb_count, expected_visible_pixels);
          frame_ok = 1'b0;
        end else begin
          raster_index = 0;
          raster_mismatch_count = 0;
          first_bad_x = 0;
          first_bad_y = 0;
          first_bad_actual_rgb = '0;
          first_bad_expected_rgb = '0;

          for (int unsigned y_idx = 0; y_idx < cfg_word_to_uint(cfg.mode.timing_cfg.v_visible);
               y_idx++) begin
            for (int unsigned x_idx = 0;
                 x_idx < cfg_word_to_uint(cfg.mode.timing_cfg.h_visible); x_idx++) begin
              expected_rgb = expected_pixel(expected_pattern, COORD_W'(x_idx), COORD_W'(y_idx),
                                            cfg.mode, cfg.solid_red, cfg.solid_green,
                                            cfg.solid_blue);
              if (frame_obs.visible_rgb[raster_index] !== expected_rgb) begin
                if (raster_mismatch_count == 0) begin
                  first_bad_x = x_idx;
                  first_bad_y = y_idx;
                  first_bad_actual_rgb = frame_obs.visible_rgb[raster_index];
                  first_bad_expected_rgb = expected_rgb;
                end
                raster_mismatch_count++;
              end
              raster_index++;
            end
          end

          if (raster_mismatch_count != 0) begin
            $error("T=%0t [Scoreboard] FAIL raster mismatches=%0d first=(%0d,%0d) rgb=0x%0h expected=0x%0h",
                   $time, raster_mismatch_count, first_bad_x, first_bad_y, first_bad_actual_rgb,
                   first_bad_expected_rgb);
            frame_ok = 1'b0;
          end
        end

        for (int sample_idx = 0; sample_idx < SAMPLE_COUNT; sample_idx++) begin
          if (!frame_obs.sample_valid[sample_idx]) begin
            $error("T=%0t [Scoreboard] FAIL missing sample %0d at (%0d,%0d)", $time,
                   sample_idx, frame_obs.sample_x[sample_idx], frame_obs.sample_y[sample_idx]);
            frame_ok = 1'b0;
          end else begin
            expected_rgb = expected_pixel(expected_pattern, frame_obs.sample_x[sample_idx],
                                          frame_obs.sample_y[sample_idx], cfg.mode, cfg.solid_red,
                                          cfg.solid_green, cfg.solid_blue);
            if (frame_obs.sample_rgb[sample_idx] !== expected_rgb) begin
              $error("T=%0t [Scoreboard] FAIL sample %0d rgb=0x%0h expected=0x%0h", $time,
                     sample_idx, frame_obs.sample_rgb[sample_idx], expected_rgb);
              frame_ok = 1'b0;
            end
          end
        end

        if (frame_ok) begin
          $display("T=%0t [Scoreboard] PASS frame=%0d scenario=%s", $time, frame_idx,
                   cfg.label);
        end

        return frame_ok;
      end
    endfunction

    task run();
      $display("T=%0t [Scoreboard] Starting", $time);
      forever begin
        video_transaction       cfg;
        video_frame_observation frame_obs;

        cfg_mbx.get(cfg);
        cfg.print("ScoreboardCfg");
        for (int unsigned frame_idx = 0; frame_idx < cfg.frames_to_check; frame_idx++) begin
          scb_mbx.get(frame_obs);
          frame_obs.print("ScoreboardObs");
          if (check_frame(cfg, frame_idx, frame_obs)) begin
            pass_cnt++;
          end else begin
            fail_cnt++;
          end
        end
        ->scb_done;
      end
    endtask

    function void report();
      $display("=== SCOREBOARD SUMMARY: PASS=%0d FAIL=%0d ===", pass_cnt, fail_cnt);
    endfunction
  endclass

  class environment;
    generator                    g0;
    driver                       d0;
    monitor                      m0;
    scoreboard                   s0;
    virtual video_pipeline_if #(COLOR_W, COORD_W, PATTERN_W, FRAMES_COUNTER_W) vif;
    mailbox #(video_transaction) drv_mbx;
    mailbox #(video_transaction) cfg_mbx;
    mailbox #(video_frame_observation) scb_mbx;
    event                        drv_done;
    event                        scb_done;

    function new();
      g0 = new();
      d0 = new();
      m0 = new();
      s0 = new();
      drv_mbx = new();
      cfg_mbx = new();
      scb_mbx = new();

      g0.drv_mbx = drv_mbx;
      d0.drv_mbx = drv_mbx;
      d0.cfg_mbx = cfg_mbx;
      s0.cfg_mbx = cfg_mbx;
      m0.scb_mbx = scb_mbx;
      s0.scb_mbx = scb_mbx;
      g0.drv_done = drv_done;
      d0.drv_done = drv_done;
      d0.scb_done = scb_done;
      s0.scb_done = scb_done;
    endfunction

    virtual task run();
      if (vif == null) begin
        $fatal(1, "T=%0t [Environment] virtual interface not assigned", $time);
      end
      d0.vif = vif;
      m0.vif = vif;

      fork
        g0.run();
        d0.run();
        m0.run();
        s0.run();
      join_any

      disable fork;
      s0.report();
    endtask
  endclass

  class test;
    environment e0;

    function new();
      e0 = new();
    endfunction

    virtual task run();
      e0.g0.num = 4;
      e0.run();
    endtask
  endclass
endpackage