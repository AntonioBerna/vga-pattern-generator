/**
 * @module pattern_generator_axis
 * @brief Generates a parameterized video pattern frame as an AXIS-like stream.
 *
 * From the selected pattern and frame geometry, the module computes the
 * current pixel color, drives `tuser` on the first pixel of the frame, and
 * drives `tlast` at the end of each visible line. The internal coordinates
 * advance only when the downstream sink accepts the current beat.
 * @param COLOR_W Bits per color channel.
 * @param COORD_W Width of the internal x/y counters.
 * @param PATTERN_W Width of the pattern-select input.
 * @port frame_width_i Visible frame width in pixels.
 * @port frame_height_i Visible frame height in pixels.
 * @port pattern_select_i Pattern selector for the pixel generator.
 * @port solid_red_i Red value used by the solid-color pattern.
 * @port solid_green_i Green value used by the solid-color pattern.
 * @port solid_blue_i Blue value used by the solid-color pattern.
 * @port clk_i System clock.
 * @port rst_i Active-high synchronous reset.
 * @port m_tdata_o Generated pixel payload.
 * @port m_tvalid_o Generated payload-valid qualifier.
 * @port m_tready_i Backpressure from the downstream sink.
 * @port m_tlast_o End-of-line marker for the generated stream.
 * @port m_tuser_o Start-of-frame marker for the generated stream.
 */
module pattern_generator_axis #(
    parameter int COLOR_W   = 8,
    parameter int COORD_W   = 16,
    parameter int PATTERN_W = 3
) (
    input  logic [  (COORD_W)-1:0] frame_width_i,
    input  logic [  (COORD_W)-1:0] frame_height_i,
    input  logic [  PATTERN_W-1:0] pattern_select_i,
    input  logic [    COLOR_W-1:0] solid_red_i,
    input  logic [    COLOR_W-1:0] solid_green_i,
    input  logic [    COLOR_W-1:0] solid_blue_i,
    input  logic                   clk_i,
    input  logic                   rst_i,
    output logic [(3*COLOR_W)-1:0] m_tdata_o,
    output logic                   m_tvalid_o,
    input  logic                   m_tready_i,
    output logic                   m_tlast_o,
    output logic                   m_tuser_o
);
  localparam longint unsigned CHANNEL_MAX_C = (64'd1 << COLOR_W) - 1;

  logic [    COORD_W-1:0] x_r;
  logic [    COORD_W-1:0] y_r;
  logic                   config_valid_w;
  logic [(3*COLOR_W)-1:0] pixel_w;

  function automatic logic [COLOR_W-1:0] from_u8(input logic [7:0] value);
    begin
      from_u8 = COLOR_W'(((64'(value) * CHANNEL_MAX_C) + 64'd127) / 64'd255);
    end
  endfunction

  function automatic logic [COLOR_W-1:0] scale_to_channel(input longint unsigned value,
                                                          input longint unsigned span);
    begin
      if (span <= 1) begin
        scale_to_channel = '0;
      end else begin
        scale_to_channel = COLOR_W'((value * CHANNEL_MAX_C) / (span - 1));
      end
    end
  endfunction

  function automatic logic [(3*COLOR_W)-1:0] pixel_for_pattern(
      input logic [PATTERN_W-1:0] pattern_select, input logic [COORD_W-1:0] x,
      input logic [COORD_W-1:0] y, input logic [COORD_W-1:0] width,
      input logic [COORD_W-1:0] height, input logic [COLOR_W-1:0] solid_red,
      input logic [COLOR_W-1:0] solid_green, input logic [COLOR_W-1:0] solid_blue);
    logic            [COLOR_W-1:0] red;
    logic            [COLOR_W-1:0] green;
    logic            [COLOR_W-1:0] blue;
    longint unsigned               x_value;
    longint unsigned               y_value;
    longint unsigned               width_value;
    longint unsigned               height_value;
    int unsigned                   vertical_bin;
    int unsigned                   horizontal_bin;
    bit                            checker_on;
    bit                            grid_on;
    begin
      red = '0;
      green = '0;
      blue = '0;

      x_value = 64'(x);
      y_value = 64'(y);
      width_value = 64'(width);
      height_value = 64'(height);

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
          red   = solid_red;
          green = solid_green;
          blue  = solid_blue;
        end

        PATTERN_W'(1): begin
          unique case (vertical_bin)
            0: begin
              red   = from_u8(8'hff);
              green = from_u8(8'h00);
              blue  = from_u8(8'h00);
            end
            1: begin
              red   = from_u8(8'hff);
              green = from_u8(8'h80);
              blue  = from_u8(8'h00);
            end
            2: begin
              red   = from_u8(8'hff);
              green = from_u8(8'hff);
              blue  = from_u8(8'h00);
            end
            3: begin
              red   = from_u8(8'h00);
              green = from_u8(8'hff);
              blue  = from_u8(8'h00);
            end
            4: begin
              red   = from_u8(8'h00);
              green = from_u8(8'hff);
              blue  = from_u8(8'hff);
            end
            5: begin
              red   = from_u8(8'h00);
              green = from_u8(8'h80);
              blue  = from_u8(8'hff);
            end
            6: begin
              red   = from_u8(8'h40);
              green = from_u8(8'h00);
              blue  = from_u8(8'hff);
            end
            default: begin
              red   = from_u8(8'hff);
              green = from_u8(8'hff);
              blue  = from_u8(8'hff);
            end
          endcase
        end

        PATTERN_W'(2): begin
          unique case (horizontal_bin)
            0: begin
              red   = from_u8(8'h20);
              green = from_u8(8'h20);
              blue  = from_u8(8'h20);
            end
            1: begin
              red   = from_u8(8'h40);
              green = from_u8(8'h00);
              blue  = from_u8(8'h80);
            end
            2: begin
              red   = from_u8(8'h00);
              green = from_u8(8'h40);
              blue  = from_u8(8'h80);
            end
            3: begin
              red   = from_u8(8'h00);
              green = from_u8(8'h80);
              blue  = from_u8(8'h40);
            end
            4: begin
              red   = from_u8(8'h80);
              green = from_u8(8'h40);
              blue  = from_u8(8'h00);
            end
            5: begin
              red   = from_u8(8'h80);
              green = from_u8(8'h00);
              blue  = from_u8(8'h40);
            end
            6: begin
              red   = from_u8(8'hc0);
              green = from_u8(8'h80);
              blue  = from_u8(8'h20);
            end
            default: begin
              red   = from_u8(8'hff);
              green = from_u8(8'hff);
              blue  = from_u8(8'hff);
            end
          endcase
        end

        PATTERN_W'(3): begin
          if (checker_on) begin
            red   = from_u8(8'hee);
            green = from_u8(8'hee);
            blue  = from_u8(8'hee);
          end else begin
            red   = from_u8(8'h22);
            green = from_u8(8'h22);
            blue  = from_u8(8'h22);
          end
        end

        PATTERN_W'(4): begin
          red   = scale_to_channel(x_value, width_value);
          green = scale_to_channel(y_value, height_value);
          blue  = scale_to_channel(x_value + y_value, width_value + height_value);
        end

        PATTERN_W'(5): begin
          if (grid_on) begin
            red   = from_u8(8'hff);
            green = from_u8(8'hff);
            blue  = from_u8(8'hff);
          end else begin
            red   = scale_to_channel(x_value, width_value) >> 1;
            green = scale_to_channel(y_value, height_value) >> 1;
            blue  = from_u8(8'h30);
          end
        end

        default: begin
          red   = from_u8(8'hff);
          green = from_u8(8'h00);
          blue  = from_u8(8'hff);
        end
      endcase

      pixel_for_pattern = {red, green, blue};
    end
  endfunction

  assign config_valid_w = (frame_width_i != '0) && (frame_height_i != '0);
  assign pixel_w = pixel_for_pattern(
      pattern_select_i,
      x_r,
      y_r,
      frame_width_i,
      frame_height_i,
      solid_red_i,
      solid_green_i,
      solid_blue_i
  );

  assign m_tdata_o = pixel_w;
  assign m_tvalid_o = config_valid_w;
  assign m_tuser_o = config_valid_w && (x_r == '0) && (y_r == '0);
  assign m_tlast_o = config_valid_w && (x_r == (frame_width_i - 1'b1));

  always_ff @(posedge clk_i) begin
    if (rst_i || !config_valid_w) begin
      x_r <= '0;
      y_r <= '0;
    end else if (m_tvalid_o && m_tready_i) begin
      if (x_r == (frame_width_i - 1'b1)) begin
        x_r <= '0;
        if (y_r == (frame_height_i - 1'b1)) begin
          y_r <= '0;
        end else begin
          y_r <= y_r + 1'b1;
        end
      end else begin
        x_r <= x_r + 1'b1;
      end
    end
  end
endmodule
