module pattern_generator_axis (
    input logic                       clk_i,
    input logic                       rst_i,
    input logic                [11:0] frame_width_i,
    input logic                [11:0] frame_height_i,
    input logic                [ 2:0] pattern_select_i,
          axis_video_if.source        m_axis
);
  logic [11:0] x_r;
  logic [11:0] y_r;
  logic [23:0] pixel_w;

  function automatic logic [7:0] scale_to_byte(input int unsigned value, input int unsigned span);
    begin
      if (span <= 1) begin
        return 8'd0;
      end else begin
        return 8'((value * 255) / (span - 1));
      end
    end
  endfunction

  function automatic logic [23:0] pixel_for_pattern(
      input logic [2:0] pattern_select, input int unsigned x, input int unsigned y,
      input int unsigned width, input int unsigned height);
    logic [7:0] red;
    logic [7:0] green;
    logic [7:0] blue;
    int unsigned vertical_bin;
    int unsigned horizontal_bin;
    bit checker_on;
    bit grid_on;
    begin
      red = 8'd0;
      green = 8'd0;
      blue = 8'd0;

      vertical_bin = (width == 0) ? 0 : ((x * 8) / width);
      horizontal_bin = (height == 0) ? 0 : ((y * 8) / height);
      if (vertical_bin > 7) begin
        vertical_bin = 7;
      end
      if (horizontal_bin > 7) begin
        horizontal_bin = 7;
      end

      checker_on = x[5] ^ y[5];
      grid_on = (x[4:0] == 5'd0) || (y[4:0] == 5'd0);

      unique case (pattern_select)
        3'd0: begin
          red   = 8'h18;
          green = 8'h80;
          blue  = 8'hf0;
        end

        3'd1: begin
          unique case (vertical_bin)
            0: begin
              red   = 8'hff;
              green = 8'h00;
              blue  = 8'h00;
            end
            1: begin
              red   = 8'hff;
              green = 8'h80;
              blue  = 8'h00;
            end
            2: begin
              red   = 8'hff;
              green = 8'hff;
              blue  = 8'h00;
            end
            3: begin
              red   = 8'h00;
              green = 8'hff;
              blue  = 8'h00;
            end
            4: begin
              red   = 8'h00;
              green = 8'hff;
              blue  = 8'hff;
            end
            5: begin
              red   = 8'h00;
              green = 8'h80;
              blue  = 8'hff;
            end
            6: begin
              red   = 8'h40;
              green = 8'h00;
              blue  = 8'hff;
            end
            default: begin
              red   = 8'hff;
              green = 8'hff;
              blue  = 8'hff;
            end
          endcase
        end

        3'd2: begin
          unique case (horizontal_bin)
            0: begin
              red   = 8'h20;
              green = 8'h20;
              blue  = 8'h20;
            end
            1: begin
              red   = 8'h40;
              green = 8'h00;
              blue  = 8'h80;
            end
            2: begin
              red   = 8'h00;
              green = 8'h40;
              blue  = 8'h80;
            end
            3: begin
              red   = 8'h00;
              green = 8'h80;
              blue  = 8'h40;
            end
            4: begin
              red   = 8'h80;
              green = 8'h40;
              blue  = 8'h00;
            end
            5: begin
              red   = 8'h80;
              green = 8'h00;
              blue  = 8'h40;
            end
            6: begin
              red   = 8'hc0;
              green = 8'h80;
              blue  = 8'h20;
            end
            default: begin
              red   = 8'hff;
              green = 8'hff;
              blue  = 8'hff;
            end
          endcase
        end

        3'd3: begin
          if (checker_on) begin
            red   = 8'hee;
            green = 8'hee;
            blue  = 8'hee;
          end else begin
            red   = 8'h22;
            green = 8'h22;
            blue  = 8'h22;
          end
        end

        3'd4: begin
          red   = scale_to_byte(x, width);
          green = scale_to_byte(y, height);
          blue  = scale_to_byte(x + y, width + height);
        end

        3'd5: begin
          if (grid_on) begin
            red   = 8'hff;
            green = 8'hff;
            blue  = 8'hff;
          end else begin
            red   = scale_to_byte(x, width) >> 1;
            green = scale_to_byte(y, height) >> 1;
            blue  = 8'h30;
          end
        end

        default: begin
          red   = 8'hff;
          green = 8'h00;
          blue  = 8'hff;
        end
      endcase

      return {red, green, blue};
    end
  endfunction

  assign pixel_w = pixel_for_pattern(
      pattern_select_i, int'(x_r), int'(y_r), int'(frame_width_i), int'(frame_height_i)
  );

  assign m_axis.tdata = pixel_w;
  assign m_axis.tvalid = 1'b1;
  assign m_axis.tuser = (x_r == 12'd0) && (y_r == 12'd0);
  assign m_axis.tlast = (x_r == (frame_width_i - 12'd1));

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      x_r <= 12'd0;
      y_r <= 12'd0;
    end else if (m_axis.tvalid && m_axis.tready) begin
      if (x_r == (frame_width_i - 12'd1)) begin
        x_r <= 12'd0;
        if (y_r == (frame_height_i - 12'd1)) begin
          y_r <= 12'd0;
        end else begin
          y_r <= y_r + 12'd1;
        end
      end else begin
        x_r <= x_r + 12'd1;
      end
    end
  end
endmodule
