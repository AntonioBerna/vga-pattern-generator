module video_timing_gen (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [11:0] h_visible_i,
    input  logic [11:0] h_front_i,
    input  logic [11:0] h_sync_i,
    input  logic [11:0] h_back_i,
    input  logic [11:0] h_total_i,
    input  logic [11:0] v_visible_i,
    input  logic [11:0] v_front_i,
    input  logic [11:0] v_sync_i,
    input  logic [11:0] v_back_i,
    input  logic [11:0] v_total_i,
    output logic [11:0] x_o,
    output logic [11:0] y_o,
    output logic        hsync_o,
    output logic        vsync_o,
    output logic        visible_o,
    output logic        frame_start_o
);
  logic [11:0] x_r;
  logic [11:0] y_r;
  logic [12:0] h_total_calc_w;
  logic [12:0] v_total_calc_w;
  logic        h_cfg_valid_w;
  logic        v_cfg_valid_w;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      x_r <= 12'd0;
      y_r <= 12'd0;
    end else if (x_r == (h_total_i - 12'd1)) begin
      x_r <= 12'd0;
      if (y_r == (v_total_i - 12'd1)) begin
        y_r <= 12'd0;
      end else begin
        y_r <= y_r + 12'd1;
      end
    end else begin
      x_r <= x_r + 12'd1;
    end
  end

  always_comb begin
    x_o = x_r;
    y_o = y_r;

    h_total_calc_w = {1'b0, h_visible_i} + {1'b0, h_front_i} + {1'b0, h_sync_i} + {1'b0, h_back_i};
    v_total_calc_w = {1'b0, v_visible_i} + {1'b0, v_front_i} + {1'b0, v_sync_i} + {1'b0, v_back_i};
    h_cfg_valid_w = (h_total_calc_w == {1'b0, h_total_i});
    v_cfg_valid_w = (v_total_calc_w == {1'b0, v_total_i});

    visible_o = h_cfg_valid_w && v_cfg_valid_w && (x_r < h_visible_i) && (y_r < v_visible_i);
    frame_start_o = h_cfg_valid_w && v_cfg_valid_w && (x_r == 12'd0) && (y_r == 12'd0);

    hsync_o = !((x_r >= (h_visible_i + h_front_i)) && (x_r < (h_visible_i + h_front_i + h_sync_i)));
    vsync_o = !((y_r >= (v_visible_i + v_front_i)) && (y_r < (v_visible_i + v_front_i + v_sync_i)));
  end
endmodule
