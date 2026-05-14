/**
 * @module video_rate_gen
 * @brief Generates a pixel clock-enable from the input clock and target pixel rate.
 *
 * The block uses a fractional accumulator: on each cycle it adds the requested
 * pixel frequency and asserts `pixel_tick_o` when the accumulation exceeds the
 * input clock frequency. This provides an accurate average enable rate without
 * introducing a second clock domain.
 * @port clk_i System clock.
 * @port rst_i Active-high synchronous reset.
 * @port rate_cfg_i Grouped runtime configuration for enable, input clock, and target pixel clock.
 * @port pixel_tick_o Clock-enable pulse used to advance visible video logic.
 * @port config_error_o High when the requested rate configuration is invalid.
 */
module video_rate_gen (
    input  logic                             clk_i,
    input  logic                             rst_i,
    input  video_types_pkg::video_rate_cfg_t rate_cfg_i,
    output logic                             pixel_tick_o,
    output logic                             config_error_o
);
  logic [31:0] accumulator_r;
  logic [32:0] accumulator_sum_w;
  logic        accumulator_next_msb_w;
  logic [31:0] accumulator_next_w;

  assign accumulator_sum_w = {1'b0, accumulator_r} + {1'b0, rate_cfg_i.pixel_clk_hz};
  assign {accumulator_next_msb_w, accumulator_next_w} =
      accumulator_sum_w - {1'b0, rate_cfg_i.input_clk_hz};
  assign config_error_o = rate_cfg_i.enable && ((rate_cfg_i.input_clk_hz == 32'd0)
                     || (rate_cfg_i.pixel_clk_hz == 32'd0)
                     || (rate_cfg_i.pixel_clk_hz > rate_cfg_i.input_clk_hz));

  always_ff @(posedge clk_i) begin
    if (rst_i || !rate_cfg_i.enable || config_error_o) begin
      accumulator_r <= 32'd0;
      pixel_tick_o  <= 1'b0;
    end else if (accumulator_sum_w >= {1'b0, rate_cfg_i.input_clk_hz}) begin
      accumulator_r <= accumulator_next_w;
      pixel_tick_o  <= !accumulator_next_msb_w;
    end else begin
      accumulator_r <= accumulator_sum_w[31:0];
      pixel_tick_o  <= 1'b0;
    end
  end
endmodule
