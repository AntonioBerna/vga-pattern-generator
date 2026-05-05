module video_pipeline_top (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [ 2:0] pattern_select_i,
    input  logic [ 1:0] mode_select_i,
    output logic [ 1:0] active_mode_o,
    output logic        hsync_o,
    output logic        vsync_o,
    output logic [ 7:0] red_o,
    output logic [ 7:0] green_o,
    output logic [ 7:0] blue_o,
    output logic        visible_o,
    output logic [11:0] x_o,
    output logic [11:0] y_o,
    output logic        stream_error_o
);
  logic [ 1:0] active_mode_r;
  logic [ 1:0] capture_mode_r;
  logic [ 2:0] capture_pattern_r;
  logic        capture_start_r;
  logic        activate_pending_r;
  logic        capture_path_rst_w;
  logic        display_rst_w;

  logic [11:0] active_h_visible_cfg;
  logic [11:0] active_h_front_cfg;
  logic [11:0] active_h_sync_cfg;
  logic [11:0] active_h_back_cfg;
  logic [11:0] active_h_total_cfg;
  logic [11:0] active_v_visible_cfg;
  logic [11:0] active_v_front_cfg;
  logic [11:0] active_v_sync_cfg;
  logic [11:0] active_v_back_cfg;
  logic [11:0] active_v_total_cfg;

  logic [11:0] capture_h_visible_cfg;
  logic [11:0] capture_v_visible_cfg;

  logic        frame_valid_w;
  logic        capture_busy_w;
  logic        update_pending_w;
  logic        frame_swapped_w;
  logic        framebuffer_error_w;
  logic        vga_stream_error_w;
  logic        activate_now_w;

  axis_video_if pattern_stream ();
  axis_video_if fifo_stream ();
  axis_video_if framebuffer_stream ();

  task automatic decode_visible(input logic [1:0] mode_select, output logic [11:0] h_visible,
                                output logic [11:0] v_visible);
    begin
      unique case (mode_select)
        2'd0: begin
          h_visible = 12'd640;
          v_visible = 12'd480;
        end

        2'd1: begin
          h_visible = 12'd800;
          v_visible = 12'd600;
        end

        2'd2: begin
          h_visible = 12'd1024;
          v_visible = 12'd768;
        end

        default: begin
          h_visible = 12'd640;
          v_visible = 12'd480;
        end
      endcase
    end
  endtask

  task automatic decode_mode(
      input logic [1:0] mode_select, output logic [11:0] h_visible, output logic [11:0] h_front,
      output logic [11:0] h_sync, output logic [11:0] h_back, output logic [11:0] h_total,
      output logic [11:0] v_visible, output logic [11:0] v_front, output logic [11:0] v_sync,
      output logic [11:0] v_back, output logic [11:0] v_total);
    begin
      unique case (mode_select)
        2'd0: begin
          h_visible = 12'd640;
          h_front = 12'd16;
          h_sync = 12'd96;
          h_back = 12'd48;
          h_total = 12'd800;

          v_visible = 12'd480;
          v_front = 12'd10;
          v_sync = 12'd2;
          v_back = 12'd33;
          v_total = 12'd525;
        end

        2'd1: begin
          h_visible = 12'd800;
          h_front = 12'd40;
          h_sync = 12'd128;
          h_back = 12'd88;
          h_total = 12'd1056;

          v_visible = 12'd600;
          v_front = 12'd1;
          v_sync = 12'd4;
          v_back = 12'd23;
          v_total = 12'd628;
        end

        2'd2: begin
          h_visible = 12'd1024;
          h_front = 12'd24;
          h_sync = 12'd136;
          h_back = 12'd160;
          h_total = 12'd1344;

          v_visible = 12'd768;
          v_front = 12'd3;
          v_sync = 12'd6;
          v_back = 12'd29;
          v_total = 12'd806;
        end

        default: begin
          h_visible = 12'd640;
          h_front = 12'd16;
          h_sync = 12'd96;
          h_back = 12'd48;
          h_total = 12'd800;

          v_visible = 12'd480;
          v_front = 12'd10;
          v_sync = 12'd2;
          v_back = 12'd33;
          v_total = 12'd525;
        end
      endcase
    end
  endtask

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      active_mode_r <= mode_select_i;
      capture_mode_r <= mode_select_i;
      capture_pattern_r <= pattern_select_i;
      capture_start_r <= 1'b0;
      activate_pending_r <= 1'b0;
    end else begin
      capture_start_r <= 1'b0;

      if (frame_swapped_w) begin
        activate_pending_r <= 1'b1;
      end

      if (activate_now_w) begin
        active_mode_r <= capture_mode_r;
        activate_pending_r <= 1'b0;
      end

      if (!capture_busy_w && !update_pending_w) begin
        if (!frame_valid_w) begin
          capture_mode_r <= mode_select_i;
          capture_pattern_r <= pattern_select_i;
          capture_start_r <= 1'b1;
        end else if ((mode_select_i != capture_mode_r)
                    || (pattern_select_i != capture_pattern_r)) begin
          capture_mode_r <= mode_select_i;
          capture_pattern_r <= pattern_select_i;
          capture_start_r <= 1'b1;
        end
      end
    end
  end

  always_comb begin
    decode_mode(active_mode_r, active_h_visible_cfg, active_h_front_cfg, active_h_sync_cfg,
                active_h_back_cfg, active_h_total_cfg, active_v_visible_cfg, active_v_front_cfg,
                active_v_sync_cfg, active_v_back_cfg, active_v_total_cfg);

    decode_visible(capture_mode_r, capture_h_visible_cfg, capture_v_visible_cfg);
  end

  assign capture_path_rst_w = rst_i || capture_start_r;
  assign activate_now_w = activate_pending_r && visible_o && (x_o == 12'd0) && (y_o == 12'd0);
  assign display_rst_w = rst_i || !frame_valid_w;
  assign active_mode_o = active_mode_r;

  pattern_generator_axis pattern_generator_i (
      .clk_i           (clk_i),
      .rst_i           (capture_path_rst_w),
      .frame_width_i   (capture_h_visible_cfg),
      .frame_height_i  (capture_v_visible_cfg),
      .pattern_select_i(capture_pattern_r),
      .m_axis          (pattern_stream)
  );

  axis_fifo #(
      .DEPTH(32)
  ) axis_fifo_i (
      .clk_i (clk_i),
      .rst_i (capture_path_rst_w),
      .s_axis(pattern_stream),
      .m_axis(fifo_stream)
  );

  axis_framebuffer axis_framebuffer_i (
      .clk_i              (clk_i),
      .rst_i              (rst_i),
      .capture_start_i    (capture_start_r),
      .capture_width_i    (capture_h_visible_cfg),
      .capture_height_i   (capture_v_visible_cfg),
      .display_width_i    (active_h_visible_cfg),
      .display_height_i   (active_v_visible_cfg),
      .s_axis             (fifo_stream),
      .m_axis             (framebuffer_stream),
      .frame_valid_o      (frame_valid_w),
      .capture_busy_o     (capture_busy_w),
      .update_pending_o   (update_pending_w),
      .frame_swapped_o    (frame_swapped_w),
      .framebuffer_error_o(framebuffer_error_w)
  );

  axis_to_vga axis_to_vga_i (
      .clk_i         (clk_i),
      .rst_i         (display_rst_w),
      .h_visible_i   (active_h_visible_cfg),
      .h_front_i     (active_h_front_cfg),
      .h_sync_i      (active_h_sync_cfg),
      .h_back_i      (active_h_back_cfg),
      .h_total_i     (active_h_total_cfg),
      .v_visible_i   (active_v_visible_cfg),
      .v_front_i     (active_v_front_cfg),
      .v_sync_i      (active_v_sync_cfg),
      .v_back_i      (active_v_back_cfg),
      .v_total_i     (active_v_total_cfg),
      .s_axis        (framebuffer_stream),
      .x_o           (x_o),
      .y_o           (y_o),
      .hsync_o       (hsync_o),
      .vsync_o       (vsync_o),
      .visible_o     (visible_o),
      .red_o         (red_o),
      .green_o       (green_o),
      .blue_o        (blue_o),
      .stream_error_o(vga_stream_error_w)
  );

  assign stream_error_o = framebuffer_error_w || vga_stream_error_w;
endmodule
