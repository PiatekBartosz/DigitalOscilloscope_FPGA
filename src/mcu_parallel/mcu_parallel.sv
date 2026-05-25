// mcu_parallel.sv – Bus_2_STM_Controller-inspired, 14-bit bidirectional data bus.
//
// READ path is purely combinational (like VHDL read_mux): the FPGA asserts data_oe
// and drives data_out as soon as rw=0 and addr are stable.  No req strobe needed;
// the MCU simply sets addr/rw=0, waits for propagation, and samples the bus.
//
// WRITE path is registered on the rising edge of req (like VHDL write_2_altera).
// Write data arrives on data_in[13:0] (the MCU drives the 14-bit bus; FPGA reads it).
//
// INCREMENT: a rising edge on mcu.inc pulses o_read_advance for one FPGA clock cycle,
// advancing the sample-buffer read pointer.  The next CH1/CH2 pair then becomes
// available combinationally on the bus for the MCU to read.
//
// Register map  (addr = mcu.addr[2:0])
//
//   READ
//   addr  Data on bus [13:0]
//   0x0   BUILD   = 14'h089
//   0x1   VERSION = 14'h007
//   0x2   CH1 sample [13:0]
//   0x3   CH2 sample [13:0]
//   0x4   Status: [0]=fifo_ovf  [1]=batch_rdy  [2]=sdram_bsy
//   0x5   CTRL readback: [2:0]=flags  [13:3]=decim_factor
//   0x6   0 (reserved)
//   0x7   14'h02B (default)
//
//   WRITE  (write data in data_in[13:0])
//   addr=5   CTRL:        [0]=capture_en  [1]=mock_en  [2]=reset_fifo  [13:3]=decim_factor
//   addr=6   SAMPLE_SIZE: log2(sample count), 4-bit, range 0–13
//   addr=7   RESET:       clears all control registers

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

    output logic        o_capture_enable,
    output logic        o_mock_enable,
    output logic        o_reset_fifo,
    output logic        o_read_advance,     // pulsed 1 cycle on inc rising edge
    output logic [12:0] o_sample_last_addr,
    output logic [10:0] o_decim_factor,

    mcu_parallel_if.device mcu
);

    localparam [2:0] ADDR_CTRL = 3'h5, ADDR_SAMPLE_SIZE = 3'h6, ADDR_RESET = 3'h7;

    logic        r_capture_enable;
    logic        r_mock_enable;
    logic        r_reset_fifo;
    logic [ 3:0] r_sample_size_exp;
    logic [10:0] r_decim_factor;
    logic [13:0] r_ch1_sample;
    logic [13:0] r_ch2_sample;

    // Latch incoming ADC samples
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ch1_sample <= 14'd0;
            r_ch2_sample <= 14'd0;
        end else begin
            if (i_ch1_valid) r_ch1_sample <= i_ch1_data;
            if (i_ch2_valid) r_ch2_sample <= i_ch2_data;
        end
    end

    // 2-FF synchronizer + edge detector on req (write strobe)
    logic r_req_sync0, r_req_sync1, r_req_prev;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_req_sync0 <= 1'b0;
            r_req_sync1 <= 1'b0;
            r_req_prev  <= 1'b0;
        end else begin
            r_req_sync0 <= mcu.req;
            r_req_sync1 <= r_req_sync0;
            r_req_prev  <= r_req_sync1;
        end
    end

    // 2-FF synchronizer + edge detector on inc (sample advance)
    logic r_inc_sync0, r_inc_sync1, r_inc_prev;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_inc_sync0 <= 1'b0;
            r_inc_sync1 <= 1'b0;
            r_inc_prev  <= 1'b0;
        end else begin
            r_inc_sync0 <= mcu.inc;
            r_inc_sync1 <= r_inc_sync0;
            r_inc_prev  <= r_inc_sync1;
        end
    end

    wire w_req_rising = r_req_sync1 & ~r_req_prev;
    wire w_inc_rising = r_inc_sync1 & ~r_inc_prev;

    // Write handler: latch data_in from bus on req rising edge when rw=1
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_capture_enable  <= 1'b0;
            r_mock_enable     <= 1'b0;
            r_reset_fifo      <= 1'b0;
            r_sample_size_exp <= 4'd13;
            r_decim_factor    <= 11'd0;
        end else if (w_req_rising && mcu.rw) begin
            case (mcu.addr)
                ADDR_CTRL: begin
                    r_capture_enable <= mcu.data_in[0];
                    r_mock_enable    <= mcu.data_in[1];
                    r_reset_fifo     <= mcu.data_in[2];
                    r_decim_factor   <= mcu.data_in[13:3];
                end
                ADDR_SAMPLE_SIZE: r_sample_size_exp <= mcu.data_in[3:0];
                ADDR_RESET: begin
                    r_capture_enable  <= 1'b0;
                    r_mock_enable     <= 1'b0;
                    r_reset_fifo      <= 1'b0;
                    r_sample_size_exp <= 4'd13;
                    r_decim_factor    <= 11'd0;
                end
                default:          ;
            endcase
        end
    end

    // Read mux: combinational, like VHDL read_mux process.
    // Full 14-bit output — no byte splitting required.
    always_comb begin
        case (mcu.addr)
            3'h0:    mcu.data_out = 14'h089;
            3'h1:    mcu.data_out = 14'h007;
            3'h2:    mcu.data_out = r_ch1_sample;
            3'h3:    mcu.data_out = r_ch2_sample;
            3'h4:    mcu.data_out = {11'd0, i_sdram_busy, i_batch_ready, i_fifo_overflow};
            3'h5:    mcu.data_out = {r_decim_factor, r_reset_fifo, r_mock_enable, r_capture_enable};
            3'h6:    mcu.data_out = 14'd0;
            default: mcu.data_out = 14'h02B;
        endcase
    end

    // FPGA drives 14-bit bus when MCU reads (rw=0), tristates when MCU writes (rw=1)
    assign mcu.data_oe        = ~mcu.rw;

    // Echo req back during reads (C3_Trigger_Clock_OUT behaviour from VHDL)
    assign mcu.req_echo       = mcu.req & ~mcu.rw;

    // Busy only during reset
    assign mcu.busy           = ~i_rst_n;

    // One-cycle pulse to advance sample-buffer read pointer
    assign o_read_advance     = w_inc_rising;
    assign o_capture_enable   = r_capture_enable;
    assign o_mock_enable      = r_mock_enable;
    assign o_reset_fifo       = r_reset_fifo;
    assign o_sample_last_addr = (13'd1 << r_sample_size_exp) - 13'd1;
    assign o_decim_factor     = r_decim_factor;

endmodule
