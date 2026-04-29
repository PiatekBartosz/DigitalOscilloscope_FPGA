module mock_gen #(
    parameter int CLK_FREQ_HZ    = 50_000_000,
    parameter int SAMPLE_RATE_HZ = 1_000
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_enable,
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid
);

    localparam int DIV = CLK_FREQ_HZ / SAMPLE_RATE_HZ - 1;
    localparam int CNT_W = $clog2(DIV + 1);

    logic [CNT_W-1:0] r_div_cnt;
    logic [     13:0] r_sample;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_div_cnt <= '0;
            r_sample  <= '0;
            o_valid   <= 1'b0;
        end else if (!i_enable) begin
            r_div_cnt <= '0;
            r_sample  <= '0;
            o_valid   <= 1'b0;
        end else begin
            o_valid <= 1'b0;
            if (r_div_cnt == CNT_W'(DIV)) begin
                r_div_cnt <= '0;
                r_sample  <= r_sample + 14'd1;
                o_valid   <= 1'b1;
            end else begin
                r_div_cnt <= r_div_cnt + 1'b1;
            end
        end
    end

    assign o_ch1_data = r_sample;
    assign o_ch2_data = ~r_sample;

endmodule
