module axis_skid_buffer (
    input logic                clk_i,
    input logic                rst_i,
          axis_video_if.sink   s_axis,
          axis_video_if.source m_axis
);
  logic [23:0] buffer_data_r;
  logic        buffer_last_r;
  logic        buffer_user_r;
  logic        buffer_valid_r;

  assign s_axis.tready = !buffer_valid_r || m_axis.tready;

  assign m_axis.tvalid = buffer_valid_r || s_axis.tvalid;
  assign m_axis.tdata = buffer_valid_r ? buffer_data_r : s_axis.tdata;
  assign m_axis.tlast = buffer_valid_r ? buffer_last_r : s_axis.tlast;
  assign m_axis.tuser = buffer_valid_r ? buffer_user_r : s_axis.tuser;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      buffer_data_r <= 24'd0;
      buffer_last_r <= 1'b0;
      buffer_user_r <= 1'b0;
      buffer_valid_r <= 1'b0;
    end else if (buffer_valid_r) begin
      if (m_axis.tready) begin
        if (s_axis.tvalid) begin
          buffer_data_r <= s_axis.tdata;
          buffer_last_r <= s_axis.tlast;
          buffer_user_r <= s_axis.tuser;
          buffer_valid_r <= 1'b1;
        end else begin
          buffer_valid_r <= 1'b0;
        end
      end
    end else if (s_axis.tvalid && !m_axis.tready) begin
      buffer_data_r <= s_axis.tdata;
      buffer_last_r <= s_axis.tlast;
      buffer_user_r <= s_axis.tuser;
      buffer_valid_r <= 1'b1;
    end
  end
endmodule