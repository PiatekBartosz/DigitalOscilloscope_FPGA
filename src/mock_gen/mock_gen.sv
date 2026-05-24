module mock_gen #(
    parameter int CLK_FREQ_HZ    = 50_000_000,
    parameter int SAMPLE_RATE_HZ = 1_000
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_enable,
    input  logic        i_advance,
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid
);

    localparam int DIV = CLK_FREQ_HZ / SAMPLE_RATE_HZ - 1;
    localparam int CNT_W = $clog2(DIV + 1);

    logic [CNT_W-1:0] r_div_cnt;
    logic [     12:0] r_sample;
    logic             r_pending_advance;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_div_cnt         <= '0;
            r_sample          <= '0;
            r_pending_advance <= 1'b0;
            o_valid           <= 1'b0;
        end else begin
            o_valid <= 1'b0;

            // Latch the fact that a sample was emitted; hold until advance arrives
            if (o_valid) r_pending_advance <= 1'b1;

            if (r_pending_advance && i_advance) begin
                r_sample          <= r_sample + 1'b1;
                r_pending_advance <= 1'b0;
            end

            if (i_enable) begin
                if (r_div_cnt == CNT_W'(DIV)) begin
                    r_div_cnt <= '0;
                    o_valid   <= 1'b1;
                end else r_div_cnt <= r_div_cnt + 1'b1;
            end else r_div_cnt <= '0;
        end
    end

    assign o_ch1_data = {r_sample, 1'b0};
    assign o_ch2_data = ~{r_sample, 1'b0};

endmodule
