/**
 * @module video_pipeline_top
 * @brief Parameterized video pipeline that generates patterns and converts them to VGA-like signals.
 *
 * The top-level integrates four responsibilities: pattern selection and
 * sequencing, internal or external pixel-tick generation, pixel-stream
 * production, and final conversion to coordinates, syncs, and RGB channels.
 * Resolution, timing, and frequency are all configured at runtime through the
 * module inputs.
 * @param COLOR_W Bits per color channel.
 * @param COORD_W Width of the timing and coordinate counters.
 * @param PATTERN_W Width of the pattern selection bus.
 * @param FRAMES_COUNTER_W Width of the pattern hold/advance frame counter.
 * @port clk_i System clock.
 * @port rst_i Active-high synchronous reset.
 * @port use_external_pixel_tick_i Selects the external pixel tick source when high.
 * @port external_pixel_tick_i External pixel clock-enable source.
 * @port rate_enable_i Enables the internal fractional pixel rate generator.
 * @port input_clk_hz_i Input clock frequency in hertz.
 * @port pixel_clk_hz_i Requested pixel rate in hertz.
 * @port pattern_auto_advance_i Enables frame-based pattern sequencing.
 * @port hold_last_pattern_i Holds the last sequenced pattern instead of wrapping to zero.
 * @port frames_per_step_i Number of frames to hold each pattern before advancing.
 * @port last_pattern_i Highest pattern index used by the internal sequencer.
 * @port pattern_select_i Manual pattern selection when auto-advance is disabled.
 * @port solid_red_i Red value used by the solid-color pattern.
 * @port solid_green_i Green value used by the solid-color pattern.
 * @port solid_blue_i Blue value used by the solid-color pattern.
 * @port h_visible_i Visible horizontal pixel count.
 * @port h_front_i Horizontal front-porch length.
 * @port h_sync_i Horizontal sync pulse length.
 * @port h_back_i Horizontal back-porch length.
 * @port v_visible_i Visible vertical line count.
 * @port v_front_i Vertical front-porch length.
 * @port v_sync_i Vertical sync pulse length.
 * @port v_back_i Vertical back-porch length.
 * @port hsync_active_low_i Selects active-low horizontal sync polarity.
 * @port vsync_active_low_i Selects active-low vertical sync polarity.
 * @port active_pattern_o Currently selected pattern after manual/automatic arbitration.
 * @port pixel_tick_o Pixel clock-enable used by the sink path.
 * @port frame_start_o High on the first frame position emitted by the sink.
 * @port frame_end_o High on the last frame position emitted by the sink.
 * @port hsync_o Horizontal sync output.
 * @port vsync_o Vertical sync output.
 * @port visible_o High while the sink is inside the visible region.
 * @port red_o Red channel output.
 * @port green_o Green channel output.
 * @port blue_o Blue channel output.
 * @port x_o Current x coordinate.
 * @port y_o Current y coordinate.
 * @port stream_error_o Latched stream protocol error indicator.
 * @port timing_error_o Timing configuration error indicator.
 * @port rate_error_o Rate generator configuration error indicator.
 */
module video_pipeline_top #(
    parameter int COLOR_W = 8,
    parameter int COORD_W = 16,
    parameter int PATTERN_W = 3,
    parameter int FRAMES_COUNTER_W = 16
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic                        use_external_pixel_tick_i,
    input  logic                        external_pixel_tick_i,
    input  logic                        rate_enable_i,
    input  logic [                31:0] input_clk_hz_i,
    input  logic [                31:0] pixel_clk_hz_i,
    input  logic                        pattern_auto_advance_i,
    input  logic                        hold_last_pattern_i,
    input  logic [FRAMES_COUNTER_W-1:0] frames_per_step_i,
    input  logic [       PATTERN_W-1:0] last_pattern_i,
    input  logic [       PATTERN_W-1:0] pattern_select_i,
    input  logic [         COLOR_W-1:0] solid_red_i,
    input  logic [         COLOR_W-1:0] solid_green_i,
    input  logic [         COLOR_W-1:0] solid_blue_i,
    input  logic [         COORD_W-1:0] h_visible_i,
    input  logic [         COORD_W-1:0] h_front_i,
    input  logic [         COORD_W-1:0] h_sync_i,
    input  logic [         COORD_W-1:0] h_back_i,
    input  logic [         COORD_W-1:0] v_visible_i,
    input  logic [         COORD_W-1:0] v_front_i,
    input  logic [         COORD_W-1:0] v_sync_i,
    input  logic [         COORD_W-1:0] v_back_i,
    input  logic                        hsync_active_low_i,
    input  logic                        vsync_active_low_i,
    output logic [       PATTERN_W-1:0] active_pattern_o,
    output logic                        pixel_tick_o,
    output logic                        frame_start_o,
    output logic                        frame_end_o,
    output logic                        hsync_o,
    output logic                        vsync_o,
    output logic                        visible_o,
    output logic [         COLOR_W-1:0] red_o,
    output logic [         COLOR_W-1:0] green_o,
    output logic [         COLOR_W-1:0] blue_o,
    output logic [         COORD_W-1:0] x_o,
    output logic [         COORD_W-1:0] y_o,
    output logic                        stream_error_o,
    output logic                        timing_error_o,
    output logic                        rate_error_o
);
  localparam logic [FRAMES_COUNTER_W-1:0] ONE_FRAME_C = FRAMES_COUNTER_W'(1);

  logic                               [     (3*COLOR_W)-1:0] pattern_tdata_w;
  logic                                                      pattern_tvalid_w;
  logic                                                      pattern_tready_w;
  logic                                                      pattern_tlast_w;
  logic                                                      pattern_tuser_w;
  logic                               [     (3*COLOR_W)-1:0] video_tdata_w;
  logic                                                      video_tvalid_w;
  logic                                                      video_tready_w;
  logic                                                      video_tlast_w;
  logic                                                      video_tuser_w;
  video_types_pkg::video_rate_cfg_t                          rate_cfg_w;
  video_types_pkg::video_timing_cfg_t                        timing_cfg_w;
  logic                               [       PATTERN_W-1:0] sequenced_pattern_r;
  logic                               [       PATTERN_W-1:0] active_pattern_w;
  logic                               [FRAMES_COUNTER_W-1:0] frame_count_r;
  logic                               [FRAMES_COUNTER_W-1:0] frames_per_step_w;
  logic                                                      at_last_pattern_w;
  logic                                                      internal_pixel_tick_w;
  logic                                                      rate_config_error_w;
  logic                                                      visible_frame_end_w;

  assign rate_cfg_w.enable = rate_enable_i && !use_external_pixel_tick_i;
  assign rate_cfg_w.input_clk_hz = video_types_pkg::video_cfg_word_t'(input_clk_hz_i);
  assign rate_cfg_w.pixel_clk_hz = video_types_pkg::video_cfg_word_t'(pixel_clk_hz_i);

  assign timing_cfg_w.h_visible = video_types_pkg::video_cfg_word_t'(h_visible_i);
  assign timing_cfg_w.h_front = video_types_pkg::video_cfg_word_t'(h_front_i);
  assign timing_cfg_w.h_sync = video_types_pkg::video_cfg_word_t'(h_sync_i);
  assign timing_cfg_w.h_back = video_types_pkg::video_cfg_word_t'(h_back_i);
  assign timing_cfg_w.v_visible = video_types_pkg::video_cfg_word_t'(v_visible_i);
  assign timing_cfg_w.v_front = video_types_pkg::video_cfg_word_t'(v_front_i);
  assign timing_cfg_w.v_sync = video_types_pkg::video_cfg_word_t'(v_sync_i);
  assign timing_cfg_w.v_back = video_types_pkg::video_cfg_word_t'(v_back_i);
  assign timing_cfg_w.hsync_active_low = hsync_active_low_i;
  assign timing_cfg_w.vsync_active_low = vsync_active_low_i;

  video_rate_gen video_rate_gen_i (
      .clk_i         (clk_i),
      .rst_i         (rst_i),
      .rate_cfg_i    (rate_cfg_w),
      .pixel_tick_o  (internal_pixel_tick_w),
      .config_error_o(rate_config_error_w)
  );

  assign pixel_tick_o = use_external_pixel_tick_i ? external_pixel_tick_i : internal_pixel_tick_w;
  assign rate_error_o = use_external_pixel_tick_i ? 1'b0 : rate_config_error_w;
  assign visible_frame_end_w = pixel_tick_o && visible_o
                                                        && ({1'b0, x_o} == ({1'b0, h_visible_i} - 1'b1))
                                                        && ({1'b0, y_o} == ({1'b0, v_visible_i} - 1'b1));
  assign frames_per_step_w = (frames_per_step_i == '0) ? ONE_FRAME_C : frames_per_step_i;
  assign at_last_pattern_w = (sequenced_pattern_r == last_pattern_i);

  always_ff @(posedge clk_i) begin
    if (rst_i || !pattern_auto_advance_i) begin
      sequenced_pattern_r <= '0;
      frame_count_r <= '0;
    end else if (visible_frame_end_w) begin
      if (frame_count_r == (frames_per_step_w - 1'b1)) begin
        frame_count_r <= '0;

        if (!at_last_pattern_w) begin
          sequenced_pattern_r <= sequenced_pattern_r + 1'b1;
        end else if (!hold_last_pattern_i) begin
          sequenced_pattern_r <= '0;
        end
      end else begin
        frame_count_r <= frame_count_r + 1'b1;
      end
    end
  end

  assign active_pattern_w = pattern_auto_advance_i ? sequenced_pattern_r : pattern_select_i;
  assign active_pattern_o = active_pattern_w;

  pattern_generator_axis #(
      .COLOR_W  (COLOR_W),
      .COORD_W  (COORD_W),
      .PATTERN_W(PATTERN_W)
  ) pattern_generator_i (
      .frame_width_i   (h_visible_i),
      .frame_height_i  (v_visible_i),
      .pattern_select_i(active_pattern_w),
      .solid_red_i     (solid_red_i),
      .solid_green_i   (solid_green_i),
      .solid_blue_i    (solid_blue_i),
      .clk_i           (clk_i),
      .rst_i           (rst_i),
      .m_tdata_o       (pattern_tdata_w),
      .m_tvalid_o      (pattern_tvalid_w),
      .m_tready_i      (pattern_tready_w),
      .m_tlast_o       (pattern_tlast_w),
      .m_tuser_o       (pattern_tuser_w)
  );

  axis_skid_buffer #(
      .DATA_W(3 * COLOR_W)
  ) axis_skid_buffer_i (
      .clk_i     (clk_i),
      .rst_i     (rst_i),
      .s_tdata_i (pattern_tdata_w),
      .s_tvalid_i(pattern_tvalid_w),
      .s_tready_o(pattern_tready_w),
      .s_tlast_i (pattern_tlast_w),
      .s_tuser_i (pattern_tuser_w),
      .m_tdata_o (video_tdata_w),
      .m_tvalid_o(video_tvalid_w),
      .m_tready_i(video_tready_w),
      .m_tlast_o (video_tlast_w),
      .m_tuser_o (video_tuser_w)
  );

  axis_to_vga #(
      .COLOR_W(COLOR_W),
      .COORD_W(COORD_W)
  ) axis_to_vga_i (
      .timing_cfg_i  (timing_cfg_w),
      .clk_i         (clk_i),
      .rst_i         (rst_i),
      .pixel_tick_i  (pixel_tick_o),
      .s_tdata_i     (video_tdata_w),
      .s_tvalid_i    (video_tvalid_w),
      .s_tready_o    (video_tready_w),
      .s_tlast_i     (video_tlast_w),
      .s_tuser_i     (video_tuser_w),
      .x_o           (x_o),
      .y_o           (y_o),
      .hsync_o       (hsync_o),
      .vsync_o       (vsync_o),
      .visible_o     (visible_o),
      .frame_start_o (frame_start_o),
      .frame_end_o   (frame_end_o),
      .red_o         (red_o),
      .green_o       (green_o),
      .blue_o        (blue_o),
      .stream_error_o(stream_error_o),
      .timing_error_o(timing_error_o)
  );
endmodule
