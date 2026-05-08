module video_pipeline_top (
    input  logic        clk_i,
    input  logic        rst_i,
  input  logic [15:0] sequence_frames_per_step_i,
    output logic [ 1:0] active_mode_o,
  output logic [ 2:0] active_pattern_o,
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
  logic [ 1:0] active_mode_w;
  logic [ 2:0] active_pattern_w;

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

  logic        vga_stream_error_w;
  logic        frame_end_w;
  logic        pipeline_rst_w;
  logic        sequence_advance_w;

  axis_video_if pattern_stream ();
  axis_video_if video_stream ();

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

  always_comb begin
    decode_mode(active_mode_w, active_h_visible_cfg, active_h_front_cfg, active_h_sync_cfg,
                active_h_back_cfg, active_h_total_cfg, active_v_visible_cfg,
                active_v_front_cfg, active_v_sync_cfg, active_v_back_cfg, active_v_total_cfg);
  end

  assign frame_end_w = (x_o == (active_h_total_cfg - 12'd1)) && (y_o == (active_v_total_cfg - 12'd1));
  assign pipeline_rst_w = rst_i || sequence_advance_w;
  assign active_mode_o = active_mode_w;
  assign active_pattern_o = active_pattern_w;

  pattern_sequence_ctrl pattern_sequence_ctrl_i (
      .clk_i             (clk_i),
      .rst_i             (rst_i),
      .frame_end_i       (frame_end_w),
      .frames_per_step_i (sequence_frames_per_step_i),
      .mode_select_o     (active_mode_w),
      .pattern_select_o  (active_pattern_w),
      .advance_o         (sequence_advance_w)
  );

  pattern_generator_axis pattern_generator_i (
      .clk_i           (clk_i),
      .rst_i           (pipeline_rst_w),
      .frame_width_i   (active_h_visible_cfg),
      .frame_height_i  (active_v_visible_cfg),
      .pattern_select_i(active_pattern_w),
      .m_axis          (pattern_stream)
  );

  axis_skid_buffer axis_skid_buffer_i (
      .clk_i (clk_i),
      .rst_i (pipeline_rst_w),
      .s_axis(pattern_stream),
      .m_axis(video_stream)
  );

  axis_to_vga axis_to_vga_i (
      .clk_i         (clk_i),
      .rst_i         (rst_i),
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
      .s_axis        (video_stream),
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

  assign stream_error_o = vga_stream_error_w;
endmodule
