module mcu_parallel (
    input logic i_clk,
    input logic i_rst_n,

    // Current sample pair from sample_buffer (latched on o_valid pulse)
    input logic [13:0] i_ch1_data,
    input logic [13:0] i_ch2_data,
    input logic        i_ch1_valid,
    input logic        i_ch2_valid,

    // Status from sample_buffer
    input logic i_fifo_overflow,
    input logic i_batch_ready,
    input logic i_sdram_busy,

    // Control outputs to the rest of the design
    output logic o_capture_enable,
    output logic o_mock_enable,
    output logic o_reset_fifo,

    // Pulsed for one cycle when MCU reads OP_CH2; drives sample_buffer i_read_advance
    output logic o_ch2_read_strobe,

    // Configurable capture depth: last writable address sent to sample_buffer.
    // Derived from OP_SAMPLE_SIZE register (log2 encoding; default = 13 → 8192 samples).
    output logic [12:0] o_sample_last_addr,

    mcu_parallel_if.device mcu
);

    localparam [2:0]
        OP_CH1        = 3'h0,
        OP_CH2        = 3'h1,
        OP_STATUS     = 3'h2,
        OP_CTRL_REG   = 3'h3,
        OP_SAMPLE_SIZE = 3'h4,  // log2(sample_count); 4-bit field in ctrl[6:3], range 0..13
        OP_RESET      = 3'h7;

    logic [13:0] r_ch1_sample;
    logic [13:0] r_ch2_sample;

    logic        r_capture_enable;
    logic        r_mock_enable;
    logic        r_reset_fifo;

    // log2 of the desired capture depth; 4 bits → exponent 0..13 → 1..8192 samples
    // Default 4'd13 preserves the original 8192-sample behaviour.
    logic [3:0]  r_sample_size_exp;

    // 2-FF synchronizer on the async REQ line
    logic r_req_sync0, r_req_sync1, r_req_prev;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_req_sync0 <= 1'b0;
            r_req_sync1 <= 1'b0;
        end else begin
            r_req_sync0 <= mcu.req;
            r_req_sync1 <= r_req_sync0;
        end
    end

    wire w_req_rising = r_req_sync1 & ~r_req_prev;

    // Latch samples from sample_buffer when a valid pair arrives
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ch1_sample <= 14'd0;
            r_ch2_sample <= 14'd0;
        end else begin
            if (i_ch1_valid) r_ch1_sample <= i_ch1_data;
            if (i_ch2_valid) r_ch2_sample <= i_ch2_data;
        end
    end

    // Request handler
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_req_prev        <= 1'b0;
            mcu.ack           <= 1'b0;
            mcu.data          <= 14'd0;
            r_capture_enable  <= 1'b0;
            r_mock_enable     <= 1'b0;
            r_reset_fifo      <= 1'b0;
            r_sample_size_exp <= 4'd13;
        end else begin
            r_req_prev <= r_req_sync1;

            if (w_req_rising) begin
                mcu.ack  <= 1'b1;
                mcu.data <= 14'd0;

                if (mcu.rw) begin
                    // Read
                    case (mcu.ctrl[2:0])
                        OP_CH1: mcu.data <= r_ch1_sample;
                        OP_CH2: mcu.data <= r_ch2_sample;
                        OP_STATUS:
                        mcu.data <= {11'd0, i_sdram_busy, i_batch_ready, i_fifo_overflow};
                        OP_CTRL_REG:
                        mcu.data <= {11'd0, r_reset_fifo, r_mock_enable, r_capture_enable};
                        OP_SAMPLE_SIZE:
                        // Returns actual sample count (1 << exponent) so the MCU
                        // can verify the register without decoding the exponent itself.
                        mcu.data <= 14'd1 << r_sample_size_exp;
                        OP_RESET: mcu.data <= 14'h0ADC;
                        default: mcu.data <= 14'h3FFF;
                    endcase
                end else begin
                    // Write
                    case (mcu.ctrl[2:0])
                        OP_CTRL_REG: begin
                            r_capture_enable <= mcu.ctrl[3];
                            r_mock_enable    <= mcu.ctrl[4];
                            r_reset_fifo     <= mcu.ctrl[5];
                        end
                        // ctrl[6:3] = log2(sample_count); value 0..13 → 1..8192 samples.
                        // Values > 13 are clamped to 13 by the 13-bit address width of
                        // sample_buffer, so they are harmless but should be avoided.
                        OP_SAMPLE_SIZE: r_sample_size_exp <= mcu.ctrl[6:3];
                        OP_RESET: begin
                            r_capture_enable <= 1'b0;
                            r_mock_enable    <= 1'b0;
                            r_reset_fifo     <= 1'b0;
                        end
                        default: ;
                    endcase
                end

            end else if (!r_req_sync1) begin
                mcu.ack <= 1'b0;
            end
        end
    end

    // Advance sample_buffer read pointer when MCU reads OP_CH2.
    // w_req_rising is a single-cycle strobe; ctrl is stable by then (2-FF delay).
    assign o_ch2_read_strobe = w_req_rising & mcu.rw & (mcu.ctrl[2:0] == OP_CH2);

    assign o_capture_enable   = r_capture_enable;
    assign o_mock_enable      = r_mock_enable;
    assign o_reset_fifo       = r_reset_fifo;
    // Last valid write address = (2^exponent) - 1.  At reset the exponent is 13,
    // giving LAST_ADDR = 8191, identical to the original hardcoded constant.
    assign o_sample_last_addr = (13'd1 << r_sample_size_exp) - 13'd1;

endmodule
