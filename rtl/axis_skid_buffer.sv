/**
 * @module axis_skid_buffer
 * @brief Single-beat elastic buffer for a streaming channel with line and frame markers.
 *
 * The module captures one beat when the downstream sink stalls unexpectedly,
 * keeping data, `last`, and `user` aligned. When the sink is ready, traffic
 * passes through in combinational bypass; otherwise the current beat is held
 * until the output side can accept it.
 * @param DATA_W Width of the stream payload in bits.
 * @port clk_i System clock.
 * @port rst_i Active-high synchronous reset.
 * @port s_tdata_i Upstream payload.
 * @port s_tvalid_i Upstream payload-valid qualifier.
 * @port s_tready_o Backpressure returned to the upstream source.
 * @port s_tlast_i Upstream end-of-line marker.
 * @port s_tuser_i Upstream start-of-frame marker.
 * @port m_tdata_o Downstream payload after optional buffering.
 * @port m_tvalid_o Downstream payload-valid qualifier.
 * @port m_tready_i Ready signal from the downstream sink.
 * @port m_tlast_o Downstream end-of-line marker.
 * @port m_tuser_o Downstream start-of-frame marker.
 */
module axis_skid_buffer #(
    parameter int DATA_W = 24
) (
    input  logic              clk_i,
    input  logic              rst_i,
    input  logic [DATA_W-1:0] s_tdata_i,
    input  logic              s_tvalid_i,
    output logic              s_tready_o,
    input  logic              s_tlast_i,
    input  logic              s_tuser_i,
    output logic [DATA_W-1:0] m_tdata_o,
    output logic              m_tvalid_o,
    input  logic              m_tready_i,
    output logic              m_tlast_o,
    output logic              m_tuser_o
);
  logic [DATA_W-1:0] buffer_data_r;
  logic              buffer_last_r;
  logic              buffer_user_r;
  logic              buffer_valid_r;

  assign s_tready_o = !buffer_valid_r;

  assign m_tvalid_o = buffer_valid_r || s_tvalid_i;
  assign m_tdata_o  = buffer_valid_r ? buffer_data_r : s_tdata_i;
  assign m_tlast_o  = buffer_valid_r ? buffer_last_r : s_tlast_i;
  assign m_tuser_o  = buffer_valid_r ? buffer_user_r : s_tuser_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      buffer_data_r  <= '0;
      buffer_last_r  <= 1'b0;
      buffer_user_r  <= 1'b0;
      buffer_valid_r <= 1'b0;
    end else if (buffer_valid_r) begin
      if (m_tready_i) begin
        buffer_valid_r <= 1'b0;
      end
    end else if (s_tvalid_i && !m_tready_i) begin
      buffer_data_r  <= s_tdata_i;
      buffer_last_r  <= s_tlast_i;
      buffer_user_r  <= s_tuser_i;
      buffer_valid_r <= 1'b1;
    end
  end
endmodule
