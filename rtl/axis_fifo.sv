module axis_fifo #(
    parameter int DEPTH = 16
) (
    input logic                clk_i,
    input logic                rst_i,
          axis_video_if.sink   s_axis,
          axis_video_if.source m_axis
);
  localparam int PTR_W = (DEPTH <= 2) ? 1 : $clog2(DEPTH);
  localparam logic [PTR_W:0] DEPTH_COUNT_C = (PTR_W + 1)'(DEPTH);
  localparam logic [PTR_W-1:0] LAST_PTR_C = PTR_W'(DEPTH - 1);

  logic [     23:0] data_mem     [0:DEPTH-1];
  logic             last_mem     [0:DEPTH-1];
  logic             user_mem     [0:DEPTH-1];
  logic [PTR_W-1:0] wr_ptr_r;
  logic [PTR_W-1:0] rd_ptr_r;
  logic [  PTR_W:0] count_r;
  logic             write_fire_w;
  logic             read_fire_w;

  assign s_axis.tready = (count_r < DEPTH_COUNT_C);
  assign m_axis.tvalid = (count_r != 0);
  assign m_axis.tdata  = data_mem[rd_ptr_r];
  assign m_axis.tlast  = last_mem[rd_ptr_r];
  assign m_axis.tuser  = user_mem[rd_ptr_r];

  assign write_fire_w  = s_axis.tvalid && s_axis.tready;
  assign read_fire_w   = m_axis.tvalid && m_axis.tready;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      wr_ptr_r <= '0;
      rd_ptr_r <= '0;
      count_r  <= '0;
    end else begin
      if (write_fire_w) begin
        data_mem[wr_ptr_r] <= s_axis.tdata;
        last_mem[wr_ptr_r] <= s_axis.tlast;
        user_mem[wr_ptr_r] <= s_axis.tuser;

        if (wr_ptr_r == LAST_PTR_C) begin
          wr_ptr_r <= '0;
        end else begin
          wr_ptr_r <= wr_ptr_r + 1'b1;
        end
      end

      if (read_fire_w) begin
        if (rd_ptr_r == LAST_PTR_C) begin
          rd_ptr_r <= '0;
        end else begin
          rd_ptr_r <= rd_ptr_r + 1'b1;
        end
      end

      unique case ({
        write_fire_w, read_fire_w
      })
        2'b10:   count_r <= count_r + 1'b1;
        2'b01:   count_r <= count_r - 1'b1;
        default: count_r <= count_r;
      endcase
    end
  end
endmodule
