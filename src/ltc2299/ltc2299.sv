module ltc2299 #(
    parameter int NAP_RECOVERY_CYCLES = 100
) (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_enable_a,
    input logic i_enable_b,

    output logic o_adc_oe_shdn_a_n,
    output logic o_adc_oe_shdn_b_n,

    input  logic [13:0] i_da,
    input  logic        i_of_a,
    input  logic [13:0] i_db,
    input  logic        i_of_b,

    output logic [13:0] o_data_a,
    output logic        o_overflow_a,
    output logic [13:0] o_data_b,
    output logic        o_overflow_b,
    output logic        o_valid_a,
    output logic        o_valid_b
);

    localparam int PIPELINE_LATENCY = 5;
    localparam int SETTLE_CYCLES = NAP_RECOVERY_CYCLES + PIPELINE_LATENCY;
    localparam int CNT_WIDTH = $clog2(SETTLE_CYCLES + 1);

    assign o_adc_oe_shdn_a_n = ~i_rst_n | ~i_enable_a;
    assign o_adc_oe_shdn_b_n = ~i_rst_n | ~i_enable_b;

    logic [CNT_WIDTH-1:0] r_cnt_a, r_cnt_b;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_cnt_a      <= '0;
            o_data_a     <= '0;
            o_overflow_a <= 1'b0;
            o_valid_a    <= 1'b0;
        end else begin
            o_data_a     <= i_da;
            o_overflow_a <= i_of_a;

            if (!i_enable_a) begin
                r_cnt_a   <= '0;
                o_valid_a <= 1'b0;
            end else if (r_cnt_a != CNT_WIDTH'(SETTLE_CYCLES)) begin
                r_cnt_a   <= r_cnt_a + 1'b1;
                o_valid_a <= 1'b0;
            end else begin
                o_valid_a <= 1'b1;
            end
        end
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            r_cnt_b      <= '0;
            o_data_b     <= '0;
            o_overflow_b <= 1'b0;
            o_valid_b    <= 1'b0;
        end else begin
            o_data_b     <= i_db;
            o_overflow_b <= i_of_b;

            if (!i_enable_b) begin
                r_cnt_b   <= '0;
                o_valid_b <= 1'b0;
            end else if (r_cnt_b != CNT_WIDTH'(SETTLE_CYCLES)) begin
                r_cnt_b   <= r_cnt_b + 1'b1;
                o_valid_b <= 1'b0;
            end else begin
                o_valid_b <= 1'b1;
            end
        end
    end

endmodule
