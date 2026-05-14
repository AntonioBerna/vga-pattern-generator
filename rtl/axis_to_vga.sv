/**
 * @module axis_to_vga
 * @brief Consumes an AXIS-like pixel stream and produces raster video signals.
 *
 * The module combines video timing control and the pixel-stream sink: it
 * generates coordinates and sync windows from the horizontal and vertical
 * timing configuration, accepts one pixel on each visible tick, and maps the
 * current beat to RGB outputs while also checking frame start, line end, and
 * stream underflow consistency.
 * @param COLOR_W Bits per color channel.
 * @param COORD_W Width of the raster x/y counters.
 * @port timing_cfg_i Grouped raster timing and sync-polarity configuration.
 * @port clk_i System clock.
 * @port rst_i Active-high synchronous reset.
 * @port pixel_tick_i Clock-enable pulse for one pixel-time step.
 * @port s_tdata_i Input pixel payload.
 * @port s_tvalid_i Input payload-valid qualifier.
 * @port s_tready_o Backpressure toward the pixel source.
 * @port s_tlast_i Input end-of-line marker.
 * @port s_tuser_i Input start-of-frame marker.
 * @port x_o Current raster x coordinate.
 * @port y_o Current raster y coordinate.
 * @port hsync_o Horizontal sync output.
 * @port vsync_o Vertical sync output.
 * @port visible_o High while the raster is inside the visible region.
 * @port frame_start_o High on the first visible pixel position of the frame timeline.
 * @port frame_end_o High on the last pixel position of the full frame timeline.
 * @port red_o Current red channel output.
 * @port green_o Current green channel output.
 * @port blue_o Current blue channel output.
 * @port stream_error_o High after a stream protocol mismatch or underflow.
 * @port timing_error_o High when the provided timing configuration is invalid.
 */
module axis_to_vga #(
    parameter int COLOR_W = 8,
    parameter int COORD_W = 16
) (
    input  video_types_pkg::video_timing_cfg_t                   timing_cfg_i,
    input  logic                                                 clk_i,
    input  logic                                                 rst_i,
    input  logic                                                 pixel_tick_i,
    input  logic                               [(3*COLOR_W)-1:0] s_tdata_i,
    input  logic                                                 s_tvalid_i,
    output logic                                                 s_tready_o,
    input  logic                                                 s_tlast_i,
    input  logic                                                 s_tuser_i,
    output logic                               [  (COORD_W)-1:0] x_o,
    output logic                               [  (COORD_W)-1:0] y_o,
    output logic                                                 hsync_o,
    output logic                                                 vsync_o,
    output logic                                                 visible_o,
    output logic                                                 frame_start_o,
    output logic                                                 frame_end_o,
    output logic                               [    COLOR_W-1:0] red_o,
    output logic                               [    COLOR_W-1:0] green_o,
    output logic                               [    COLOR_W-1:0] blue_o,
    output logic                                                 stream_error_o,
    output logic                                                 timing_error_o
);
  logic [    COORD_W-1:0] h_visible_w;
  logic [    COORD_W-1:0] h_front_w;
  logic [    COORD_W-1:0] h_sync_w;
  logic [    COORD_W-1:0] h_back_w;
  logic [    COORD_W-1:0] v_visible_w;
  logic [    COORD_W-1:0] v_front_w;
  logic [    COORD_W-1:0] v_sync_w;
  logic [    COORD_W-1:0] v_back_w;
  logic                   hsync_active_low_w;
  logic                   vsync_active_low_w;
  logic [    COORD_W-1:0] x_r;
  logic [    COORD_W-1:0] y_r;
  logic [  (COORD_W)-1:0] x_w;
  logic [  (COORD_W)-1:0] y_w;
  logic [      COORD_W:0] h_total_w;
  logic [      COORD_W:0] v_total_w;
  logic [      COORD_W:0] h_sync_start_w;
  logic [      COORD_W:0] h_sync_end_w;
  logic [      COORD_W:0] v_sync_start_w;
  logic [      COORD_W:0] v_sync_end_w;
  logic                   config_valid_w;
  logic                   hsync_active_w;
  logic                   vsync_active_w;
  logic                   visible_w;
  logic                   line_end_w;
  logic                   frame_start_w;
  logic                   frame_end_w;
  logic                   timing_config_error_w;
  logic                   visible_line_end_w;
  logic [(3*COLOR_W)-1:0] display_pixel_w;
  logic                   frame_error_r;
  logic                   line_error_r;
  logic                   underflow_r;

  assign h_visible_w = COORD_W'(timing_cfg_i.h_visible);
  assign h_front_w = COORD_W'(timing_cfg_i.h_front);
  assign h_sync_w = COORD_W'(timing_cfg_i.h_sync);
  assign h_back_w = COORD_W'(timing_cfg_i.h_back);
  assign v_visible_w = COORD_W'(timing_cfg_i.v_visible);
  assign v_front_w = COORD_W'(timing_cfg_i.v_front);
  assign v_sync_w = COORD_W'(timing_cfg_i.v_sync);
  assign v_back_w = COORD_W'(timing_cfg_i.v_back);
  assign hsync_active_low_w = timing_cfg_i.hsync_active_low;
  assign vsync_active_low_w = timing_cfg_i.vsync_active_low;

  assign h_total_w = {1'b0, h_visible_w} + {1'b0, h_front_w} + {1'b0, h_sync_w} + {1'b0, h_back_w};
  assign v_total_w = {1'b0, v_visible_w} + {1'b0, v_front_w} + {1'b0, v_sync_w} + {1'b0, v_back_w};
  assign h_sync_start_w = {1'b0, h_visible_w} + {1'b0, h_front_w};
  assign h_sync_end_w = h_sync_start_w + {1'b0, h_sync_w};
  assign v_sync_start_w = {1'b0, v_visible_w} + {1'b0, v_front_w};
  assign v_sync_end_w = v_sync_start_w + {1'b0, v_sync_w};
  assign config_valid_w = (h_visible_w != '0) && (v_visible_w != '0) && (h_sync_w != '0)
                       && (v_sync_w != '0) && (h_total_w != '0) && (v_total_w != '0)
                       && !h_total_w[COORD_W] && !v_total_w[COORD_W];
  assign visible_line_end_w = visible_w && ({1'b0, x_w} == ({1'b0, h_visible_w} - 1'b1));
  assign s_tready_o = pixel_tick_i && visible_w && !rst_i && !timing_config_error_w;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      x_r <= '0;
      y_r <= '0;
      frame_error_r <= 1'b0;
      line_error_r <= 1'b0;
      underflow_r <= 1'b0;
    end else if (!config_valid_w) begin
      x_r <= '0;
      y_r <= '0;
    end else if (pixel_tick_i) begin
      if ({1'b0, x_r} == (h_total_w - 1'b1)) begin
        x_r <= '0;
        if ({1'b0, y_r} == (v_total_w - 1'b1)) begin
          y_r <= '0;
        end else begin
          y_r <= y_r + 1'b1;
        end
      end else begin
        x_r <= x_r + 1'b1;
      end

      if (!timing_config_error_w && visible_w) begin
        if (s_tvalid_i) begin
          if (frame_start_w != s_tuser_i) begin
            frame_error_r <= 1'b1;
          end

          if (visible_line_end_w != s_tlast_i) begin
            line_error_r <= 1'b1;
          end
        end else begin
          underflow_r <= 1'b1;
        end
      end
    end
  end

  always_comb begin
    x_w = x_r;
    y_w = y_r;

    line_end_w = config_valid_w && ({1'b0, x_r} == (h_total_w - 1'b1));
    frame_start_w = config_valid_w && ({1'b0, x_r} == '0) && ({1'b0, y_r} == '0);
    frame_end_w = line_end_w && ({1'b0, y_r} == (v_total_w - 1'b1));
    visible_w = config_valid_w && ({1'b0, x_r} < {1'b0, h_visible_w})
             && ({1'b0, y_r} < {1'b0, v_visible_w});

    hsync_active_w = config_valid_w && ({1'b0, x_r} >= h_sync_start_w)
                  && ({1'b0, x_r} < h_sync_end_w);
    vsync_active_w = config_valid_w && ({1'b0, y_r} >= v_sync_start_w)
                  && ({1'b0, y_r} < v_sync_end_w);

    hsync_o = hsync_active_low_w ? !hsync_active_w : hsync_active_w;
    vsync_o = vsync_active_low_w ? !vsync_active_w : vsync_active_w;
    timing_config_error_w = !rst_i && !config_valid_w;
  end

  assign x_o = x_w;
  assign y_o = y_w;
  assign visible_o = visible_w;
  assign frame_start_o = frame_start_w;
  assign frame_end_o = frame_end_w;
  assign display_pixel_w = (visible_w && s_tvalid_i && !timing_config_error_w) ? s_tdata_i : '0;

  assign red_o = display_pixel_w[(3*COLOR_W)-1-:COLOR_W];
  assign green_o = display_pixel_w[(2*COLOR_W)-1-:COLOR_W];
  assign blue_o = display_pixel_w[COLOR_W-1:0];

  assign stream_error_o = frame_error_r || line_error_r || underflow_r;
  assign timing_error_o = timing_config_error_w;
endmodule
