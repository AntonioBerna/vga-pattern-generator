module axis_framebuffer #(
    parameter int MAX_FRAME_WIDTH  = 1024,
    parameter int MAX_FRAME_HEIGHT = 768
) (
    input  logic                       clk_i,
    input  logic                       rst_i,
    input  logic                       capture_start_i,
    input  logic                [11:0] capture_width_i,
    input  logic                [11:0] capture_height_i,
    input  logic                [11:0] display_width_i,
    input  logic                [11:0] display_height_i,
           axis_video_if.sink          s_axis,
           axis_video_if.source        m_axis,
    output logic                       frame_valid_o,
    output logic                       capture_busy_o,
    output logic                       update_pending_o,
    output logic                       frame_swapped_o,
    output logic                       framebuffer_error_o
);
  localparam int MAX_FRAME_PIXELS = MAX_FRAME_WIDTH * MAX_FRAME_HEIGHT;
  localparam int TOTAL_PIXELS = 2 * MAX_FRAME_PIXELS;
  localparam int BUFFER_ADDR_W = $clog2(MAX_FRAME_PIXELS);
  localparam logic [BUFFER_ADDR_W:0] MAX_FRAME_PIXELS_C = (BUFFER_ADDR_W + 1)'(MAX_FRAME_PIXELS);

  logic [23:0] frame_mem[0:TOTAL_PIXELS-1];

  logic front_select_r;
  logic capture_select_r;
  logic frame_valid_r;
  logic capture_busy_r;
  logic update_pending_r;
  logic framebuffer_error_r;
  logic frame_swapped_r;
  logic [BUFFER_ADDR_W-1:0] wr_addr_r;
  logic [BUFFER_ADDR_W-1:0] rd_addr_r;
  logic [BUFFER_ADDR_W:0] wr_addr_ext_w;
  logic [BUFFER_ADDR_W:0] rd_addr_ext_w;
  logic [11:0] capture_x_r;
  logic [11:0] read_x_r;
  logic [BUFFER_ADDR_W:0] capture_frame_pixels_r;
  logic [BUFFER_ADDR_W:0] display_frame_pixels_w;
  logic [BUFFER_ADDR_W:0] front_base_w;
  logic [BUFFER_ADDR_W:0] capture_base_w;
  logic capture_fire_w;
  logic display_fire_w;

  assign wr_addr_ext_w = {1'b0, wr_addr_r};
  assign rd_addr_ext_w = {1'b0, rd_addr_r};

  assign front_base_w = front_select_r ? MAX_FRAME_PIXELS_C : '0;
  assign capture_base_w = capture_select_r ? MAX_FRAME_PIXELS_C : '0;
  assign display_frame_pixels_w = display_width_i * display_height_i;

  assign capture_fire_w = capture_busy_r && s_axis.tvalid && s_axis.tready;
  assign display_fire_w = frame_valid_r && m_axis.tvalid && m_axis.tready;

  assign s_axis.tready = capture_busy_r;

  assign m_axis.tvalid = frame_valid_r;
  assign m_axis.tdata = frame_valid_r ? frame_mem[front_base_w+rd_addr_r] : 24'd0;
  assign m_axis.tuser = frame_valid_r && (rd_addr_r == '0);
  assign m_axis.tlast = frame_valid_r && (read_x_r == (display_width_i - 12'd1));

  assign frame_valid_o = frame_valid_r;
  assign capture_busy_o = capture_busy_r;
  assign update_pending_o = update_pending_r;
  assign frame_swapped_o = frame_swapped_r;
  assign framebuffer_error_o = framebuffer_error_r;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      front_select_r <= 1'b0;
      capture_select_r <= 1'b0;
      frame_valid_r <= 1'b0;
      capture_busy_r <= 1'b0;
      update_pending_r <= 1'b0;
      framebuffer_error_r <= 1'b0;
      frame_swapped_r <= 1'b0;
      wr_addr_r <= '0;
      rd_addr_r <= '0;
      capture_x_r <= '0;
      read_x_r <= '0;
      capture_frame_pixels_r <= '0;
    end else begin
      frame_swapped_r <= 1'b0;

      if (capture_start_i && !capture_busy_r && !update_pending_r) begin
        if ((capture_width_i == 0)
         || (capture_height_i == 0)
         || ((capture_width_i * capture_height_i) > MAX_FRAME_PIXELS)) begin
          framebuffer_error_r <= 1'b1;
        end else begin
          capture_busy_r <= 1'b1;
          capture_select_r <= frame_valid_r ? !front_select_r : 1'b0;
          wr_addr_r <= '0;
          capture_x_r <= '0;
          capture_frame_pixels_r <= capture_width_i * capture_height_i;
        end
      end

      if (capture_fire_w) begin
        frame_mem[capture_base_w+wr_addr_r] <= s_axis.tdata;

        if ((wr_addr_r == '0) && !s_axis.tuser) begin
          framebuffer_error_r <= 1'b1;
        end

        if ((wr_addr_r != '0) && s_axis.tuser) begin
          framebuffer_error_r <= 1'b1;
        end

        if ((capture_x_r == (capture_width_i - 12'd1)) && !s_axis.tlast) begin
          framebuffer_error_r <= 1'b1;
        end

        if ((capture_x_r != (capture_width_i - 12'd1)) && s_axis.tlast) begin
          framebuffer_error_r <= 1'b1;
        end

        if (wr_addr_ext_w == (capture_frame_pixels_r - 1'b1)) begin
          capture_busy_r <= 1'b0;
          wr_addr_r <= '0;
          capture_x_r <= '0;

          if (!frame_valid_r) begin
            front_select_r  <= capture_select_r;
            frame_valid_r   <= 1'b1;
            frame_swapped_r <= 1'b1;
          end else begin
            update_pending_r <= 1'b1;
          end
        end else begin
          wr_addr_r <= wr_addr_r + 1'b1;
          if (capture_x_r == (capture_width_i - 12'd1)) begin
            capture_x_r <= '0;
          end else begin
            capture_x_r <= capture_x_r + 12'd1;
          end
        end
      end

      if (display_fire_w) begin
        if (rd_addr_ext_w == (display_frame_pixels_w - 1'b1)) begin
          rd_addr_r <= '0;
          read_x_r  <= '0;

          if (update_pending_r) begin
            front_select_r   <= !front_select_r;
            update_pending_r <= 1'b0;
            frame_swapped_r  <= 1'b1;
          end
        end else begin
          rd_addr_r <= rd_addr_r + 1'b1;

          if (read_x_r == (display_width_i - 12'd1)) begin
            read_x_r <= '0;
          end else begin
            read_x_r <= read_x_r + 12'd1;
          end
        end
      end
    end
  end
endmodule
