// MCU register map: read 0=build, 1=version, 2/3=samples, 4=status, 5=control, 6=size; write 5=control, 6=size, 7=reset.

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
    input logic i_pretrigger_ready,
    input logic i_trigger_armed,

    output logic        o_capture_enable,
    output logic        o_mock_enable,
    output logic        o_reset_fifo,
    output logic        o_trigger_en,
    output logic        o_read_advance,
    output logic [12:0] o_sample_last_addr,
    output logic [12:0] o_pretrigger_count,
    output logic [10:0] o_decim_factor,

    mcu_parallel_if.device mcu
);

    localparam [2:0] ADDR_CTRL = 3'h5, ADDR_SAMPLE_SIZE = 3'h6, ADDR_RESET = 3'h7;

    logic        r_capture_enable;
    logic        r_mock_enable;
    logic        r_reset_fifo;
    logic        r_trigger_en;
    logic [ 3:0] r_sample_size_exp;
    logic [ 3:0] r_pretrigger_exp;
    logic [10:0] r_decim_factor;
    logic [13:0] r_ch1_sample;
    logic [13:0] r_ch2_sample;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ch1_sample <= 14'd0;
            r_ch2_sample <= 14'd0;
        end else begin
            if (i_ch1_valid) r_ch1_sample <= i_ch1_data;
            if (i_ch2_valid) r_ch2_sample <= i_ch2_data;
        end
    end

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

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_capture_enable  <= 1'b0;
            r_mock_enable     <= 1'b0;
            r_reset_fifo      <= 1'b0;
            r_trigger_en      <= 1'b0;
            r_sample_size_exp <= 4'd13;
            r_pretrigger_exp  <= 4'd0;
            r_decim_factor    <= 11'd0;
        end else if (w_req_rising && mcu.rw) begin
            case (mcu.addr)
                ADDR_CTRL: begin
                    r_capture_enable <= mcu.data_in[0];
                    r_mock_enable    <= mcu.data_in[1];
                    r_reset_fifo     <= mcu.data_in[2];
                    r_trigger_en     <= mcu.data_in[3];
                    r_decim_factor   <= {1'b0, mcu.data_in[13:4]};
                end
                ADDR_SAMPLE_SIZE: begin
                    r_sample_size_exp <= mcu.data_in[3:0];
                    r_pretrigger_exp  <= mcu.data_in[7:4];
                end
                ADDR_RESET: begin
                    r_capture_enable  <= 1'b0;
                    r_mock_enable     <= 1'b0;
                    r_reset_fifo      <= 1'b0;
                    r_trigger_en      <= 1'b0;
                    r_sample_size_exp <= 4'd13;
                    r_pretrigger_exp  <= 4'd0;
                    r_decim_factor    <= 11'd0;
                end
                default: ;
            endcase
        end
    end

    always_comb begin
        case (mcu.addr)
            3'h0: mcu.data_out = 14'h089;
            3'h1: mcu.data_out = 14'h007;
            3'h2: mcu.data_out = r_ch1_sample;
            3'h3: mcu.data_out = r_ch2_sample;
            3'h4:
            mcu.data_out = {
                9'd0, i_trigger_armed, i_pretrigger_ready,
                i_sdram_busy, i_batch_ready, i_fifo_overflow
            };
            3'h5:
            mcu.data_out = {
                r_decim_factor[9:0], r_trigger_en, r_reset_fifo, r_mock_enable, r_capture_enable
            };
            3'h6: mcu.data_out = {6'd0, r_pretrigger_exp, r_sample_size_exp};
            default: mcu.data_out = 14'h02B;
        endcase
    end

    assign mcu.data_oe        = ~mcu.rw;

    assign mcu.req_echo       = mcu.req & ~mcu.rw;

    assign mcu.busy           = ~i_rst_n;

    assign o_read_advance     = w_inc_rising;
    assign o_capture_enable   = r_capture_enable;
    assign o_mock_enable      = r_mock_enable;
    assign o_reset_fifo       = r_reset_fifo;
    assign o_trigger_en       = r_trigger_en;
    assign o_sample_last_addr = (13'd1 << r_sample_size_exp) - 13'd1;
    assign o_decim_factor     = r_decim_factor;

    wire [13:0] w_pretrigger_raw = (r_pretrigger_exp == 4'd0)
                                  ? 14'd0
                                  : (14'd1 << (r_pretrigger_exp - 4'd1));
    assign o_pretrigger_count = (w_pretrigger_raw > {1'b0, o_sample_last_addr})
                               ? o_sample_last_addr
                               : w_pretrigger_raw[12:0];

endmodule
