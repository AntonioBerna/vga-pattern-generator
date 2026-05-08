module pattern_sequence_ctrl #(
    parameter int FRAMES_COUNTER_W = 16
) (
    input  logic                        clk_i,
    input  logic                        rst_i,
    input  logic                        frame_end_i,
    input  logic [FRAMES_COUNTER_W-1:0] frames_per_step_i,
    output logic [                 1:0] mode_select_o,
    output logic [                 2:0] pattern_select_o,
    output logic                        advance_o
);
  localparam logic [FRAMES_COUNTER_W-1:0] ONE_FRAME_C = FRAMES_COUNTER_W'(1);
  localparam logic [2:0] LAST_STEP_C = 3'd5;

  logic [2:0] step_index_r;
  logic [FRAMES_COUNTER_W-1:0] frame_count_r;
  logic [FRAMES_COUNTER_W-1:0] frames_per_step_w;

  function automatic logic [1:0] mode_for_step(input logic [2:0] step_index);
    begin
      unique case (step_index)
        3'd0: mode_for_step = 2'd0;
        3'd1: mode_for_step = 2'd0;
        3'd2: mode_for_step = 2'd1;
        3'd3: mode_for_step = 2'd1;
        3'd4: mode_for_step = 2'd2;
        default: mode_for_step = 2'd2;
      endcase
    end
  endfunction

  function automatic logic [2:0] pattern_for_step(input logic [2:0] step_index);
    begin
      unique case (step_index)
        3'd0: pattern_for_step = 3'd0;
        3'd1: pattern_for_step = 3'd1;
        3'd2: pattern_for_step = 3'd2;
        3'd3: pattern_for_step = 3'd4;
        3'd4: pattern_for_step = 3'd3;
        default: pattern_for_step = 3'd5;
      endcase
    end
  endfunction

  assign frames_per_step_w = (frames_per_step_i == '0) ? ONE_FRAME_C : frames_per_step_i;
  assign advance_o = frame_end_i && (frame_count_r == (frames_per_step_w - 1'b1));

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      step_index_r <= '0;
      frame_count_r <= '0;
    end else if (frame_end_i) begin
      if (frame_count_r == (frames_per_step_w - 1'b1)) begin
        frame_count_r <= '0;
        if (step_index_r != LAST_STEP_C) begin
          step_index_r <= step_index_r + 1'b1;
        end
      end else begin
        frame_count_r <= frame_count_r + 1'b1;
      end
    end
  end

  assign mode_select_o = mode_for_step(step_index_r);
  assign pattern_select_o = pattern_for_step(step_index_r);
endmodule