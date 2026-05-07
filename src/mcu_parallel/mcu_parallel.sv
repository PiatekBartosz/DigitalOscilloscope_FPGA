module mcu_parallel (
    input logic i_clk,
    input logic i_rst_n,

    input logic [13:0] i_ch1_data,
    input logic [13:0] i_ch2_data,
    input logic        i_ch1_valid,
    input logic        i_ch2_valid,

    input logic i_fifo_overflow,
    input logic i_batch_ready,
    input logic i_sdram_busy,

    output logic       o_capture_enable,
    output logic       o_mock_enable,
    output logic       o_reset_fifo,
    output logic [7:0] o_sample_count,
    output logic [7:0] o_frequency,

    mcu_parallel_if.device mcu
);

    localparam logic [2:0]
        OP_CH1        = 3'h0,
        OP_CH2        = 3'h1,
        OP_STATUS     = 3'h2,
        OP_CTRL_REG   = 3'h3,
        OP_SAMPLE_CNT = 3'h4,
        OP_FREQUENCY  = 3'h5,
        OP_STREAM     = 3'h6,
        OP_RESET      = 3'h7;

    logic [13:0] r_ch1_sample;
    logic [13:0] r_ch2_sample;

    logic        r_capture_enable;
    logic        r_mock_enable;
    logic        r_reset_fifo;
    logic [ 7:0] r_sample_count;
    logic [ 7:0] r_frequency;
    logic        r_stream_enable;

    // 2-FF synchronizer: prevents metastability on the async req line and
    // gives ctrl/rw an extra 2 cycles (~40 ns at 50 MHz) to settle before
    // the FPGA latches them, eliminating spurious opcode misreads.
    logic r_req_sync0, r_req_sync1;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_req_sync0 <= 1'b0;
            r_req_sync1 <= 1'b0;
        end else begin
            r_req_sync0 <= mcu.req;
            r_req_sync1 <= r_req_sync0;
        end
    end

    logic r_req_prev;
    wire  w_req_rising = r_req_sync1 & ~r_req_prev;

    logic [ 7:0] r_ctrl_latch;
    logic        r_rw_latch;
    wire  [ 2:0] w_op = r_ctrl_latch[2:0];
    wire  [ 4:0] w_payload = r_ctrl_latch[7:3];

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ch1_sample <= 14'd0;
            r_ch2_sample <= 14'd0;
        end else begin
            if (i_ch1_valid) r_ch1_sample <= i_ch1_data;
            if (i_ch2_valid) r_ch2_sample <= i_ch2_data;
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_req_prev       <= 1'b0;
            r_ctrl_latch     <= 8'd0;
            r_rw_latch       <= 1'b0;
            mcu.ack          <= 1'b0;
            mcu.data         <= 14'd0;
            r_capture_enable <= 1'b0;
            r_mock_enable    <= 1'b0;
            r_reset_fifo     <= 1'b0;
            r_sample_count   <= 8'd0;
            r_frequency      <= 8'd0;
            r_stream_enable  <= 1'b0;
        end else begin
            r_req_prev <= r_req_sync1;

            if (w_req_rising) begin
                r_ctrl_latch <= mcu.ctrl;
                r_rw_latch   <= mcu.rw;

                mcu.ack      <= 1'b1;
                mcu.data     <= 14'd0;

                if (mcu.rw) begin
                    case (mcu.ctrl[2:0])
                        OP_CH1: mcu.data <= r_ch1_sample;
                        OP_CH2: mcu.data <= r_ch2_sample;
                        OP_STATUS:
                        mcu.data <= {11'd0, i_sdram_busy, i_batch_ready, i_fifo_overflow};
                        OP_CTRL_REG:
                        mcu.data <= {11'd0, r_reset_fifo, r_mock_enable, r_capture_enable};
                        OP_SAMPLE_CNT: mcu.data <= {9'd0, r_sample_count[4:0]};
                        OP_FREQUENCY: mcu.data <= {9'd0, r_frequency[4:0]};
                        OP_RESET: mcu.data <= 14'h0ADC;
                        default: mcu.data <= 14'h3FFF;
                    endcase
                end else begin
                    case (mcu.ctrl[2:0])
                        OP_CTRL_REG: begin
                            r_capture_enable <= mcu.ctrl[3];
                            r_mock_enable    <= mcu.ctrl[4];
                            r_reset_fifo     <= mcu.ctrl[5];
                        end
                        OP_SAMPLE_CNT: r_sample_count <= {3'd0, mcu.ctrl[7:3]};
                        OP_FREQUENCY:  r_frequency <= {3'd0, mcu.ctrl[7:3]};
                        OP_STREAM:     r_stream_enable <= mcu.ctrl[3];
                        OP_RESET: begin
                            r_capture_enable <= 1'b0;
                            r_mock_enable    <= 1'b0;
                            r_reset_fifo     <= 1'b0;
                            r_sample_count   <= 8'd0;
                            r_frequency      <= 8'd0;
                            r_stream_enable  <= 1'b0;
                        end
                        default:       ;
                    endcase
                end

            end else if (!r_req_sync1) begin
                mcu.ack <= 1'b0;
            end
        end
    end

    logic [7:0] r_irq_cnt;
    logic       r_irq_pulse;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_irq_cnt   <= 8'd0;
            r_irq_pulse <= 1'b0;
        end else begin
            r_irq_pulse <= 1'b0;
            if (i_ch1_valid) begin
                if (r_irq_cnt == 8'd0) begin
                    r_irq_pulse <= 1'b1;
                    r_irq_cnt   <= r_frequency;
                end else begin
                    r_irq_cnt <= r_irq_cnt - 1'b1;
                end
            end else begin
                r_irq_cnt <= 8'd0;
            end
        end
    end

    assign mcu.irq          = r_stream_enable & r_irq_pulse;

    assign o_capture_enable = r_capture_enable;
    assign o_mock_enable    = r_mock_enable;
    assign o_reset_fifo     = r_reset_fifo;
    assign o_sample_count   = r_sample_count;
    assign o_frequency      = r_frequency;

endmodule
