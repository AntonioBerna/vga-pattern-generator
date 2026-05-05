module axis_to_vga (
    input  logic                     clk_i,
    input  logic                     rst_i,
    input  logic              [11:0] h_visible_i,
    input  logic              [11:0] h_front_i,
    input  logic              [11:0] h_sync_i,
    input  logic              [11:0] h_back_i,
    input  logic              [11:0] h_total_i,
    input  logic              [11:0] v_visible_i,
    input  logic              [11:0] v_front_i,
    input  logic              [11:0] v_sync_i,
    input  logic              [11:0] v_back_i,
    input  logic              [11:0] v_total_i,
           axis_video_if.sink        s_axis,
    output logic              [11:0] x_o,
    output logic              [11:0] y_o,
    output logic                     hsync_o,
    output logic                     vsync_o,
    output logic                     visible_o,
    output logic              [ 7:0] red_o,
    output logic              [ 7:0] green_o,
    output logic              [ 7:0] blue_o,
    output logic                     stream_error_o
);
  logic [11:0] x_w;
  logic [11:0] y_w;
  logic        visible_w;
  logic        frame_start_w;
  logic [23:0] pixel_r;
  logic        frame_error_r;
  logic        line_error_r;
  logic        underflow_r;

  video_timing_gen timing_gen_i (
      .clk_i        (clk_i),
      .rst_i        (rst_i),
      .h_visible_i  (h_visible_i),
      .h_front_i    (h_front_i),
      .h_sync_i     (h_sync_i),
      .h_back_i     (h_back_i),
      .h_total_i    (h_total_i),
      .v_visible_i  (v_visible_i),
      .v_front_i    (v_front_i),
      .v_sync_i     (v_sync_i),
      .v_back_i     (v_back_i),
      .v_total_i    (v_total_i),
      .x_o          (x_w),
      .y_o          (y_w),
      .hsync_o      (hsync_o),
      .vsync_o      (vsync_o),
      .visible_o    (visible_w),
      .frame_start_o(frame_start_w)
  );

  assign s_axis.tready = visible_w && !rst_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pixel_r <= 24'd0;
      frame_error_r <= 1'b0;
      line_error_r <= 1'b0;
      underflow_r <= 1'b0;
    end else if (visible_w) begin
      if (s_axis.tvalid && s_axis.tready) begin
        pixel_r <= s_axis.tdata;

        if (frame_start_w && !s_axis.tuser) begin
          frame_error_r <= 1'b1;
        end

        if (!frame_start_w && s_axis.tuser) begin
          frame_error_r <= 1'b1;
        end

        if ((x_w == (h_visible_i - 12'd1)) && !s_axis.tlast) begin
          line_error_r <= 1'b1;
        end

        if ((x_w != (h_visible_i - 12'd1)) && s_axis.tlast) begin
          line_error_r <= 1'b1;
        end
      end else begin
        pixel_r <= 24'd0;
        underflow_r <= 1'b1;
      end
    end else begin
      pixel_r <= 24'd0;
    end
  end

  assign x_o = x_w;
  assign y_o = y_w;
  assign visible_o = visible_w;

  assign red_o = visible_w ? pixel_r[23:16] : 8'd0;
  assign green_o = visible_w ? pixel_r[15:8] : 8'd0;
  assign blue_o = visible_w ? pixel_r[7:0] : 8'd0;

  assign stream_error_o = frame_error_r || line_error_r || underflow_r;
endmodule
