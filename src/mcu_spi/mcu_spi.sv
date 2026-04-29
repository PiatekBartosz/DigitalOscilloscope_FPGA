module spi_master_tx #(
    parameter int CLK_IN_HZ     = 80_000_000,
    parameter int TARGET_SPI_HZ = 5_000_000
) (
    input  logic        i_clk,
    input  logic [13:0] i_data,
    output logic        o_sclk,
    output logic        o_mosi,
    output logic        o_cs_n
);

    localparam int DIVISOR = CLK_IN_HZ / (TARGET_SPI_HZ * 2);

    logic [$clog2(DIVISOR)-1:0] clk_cnt = 0;
    logic [                4:0] bit_cnt = 0;
    logic [               15:0] shift_reg;
    logic                       sclk_reg = 0;
    logic                       active = 0;

    logic [               15:0] packet_timer = 0;

    always_ff @(posedge i_clk) begin
        if (packet_timer < 16'hFFFF) begin
            packet_timer <= packet_timer + 1;
            o_cs_n       <= 1'b1;
            active       <= 0;
            sclk_reg     <= 1'b0;
        end else begin
            if (clk_cnt < (DIVISOR - 1)) begin
                clk_cnt <= clk_cnt + 1;
            end else begin
                clk_cnt <= 0;

                if (!active) begin
                    shift_reg <= {2'b00, i_data};
                    bit_cnt   <= 0;
                    active    <= 1;
                    o_cs_n    <= 1'b0;
                end else begin
                    sclk_reg <= !sclk_reg;

                    if (sclk_reg == 1'b1) begin
                        shift_reg <= {shift_reg[14:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1;

                        if (bit_cnt == 5'd15) begin
                            active       <= 0;
                            o_cs_n       <= 1'b1;
                            packet_timer <= 0;
                        end
                    end
                end
            end
        end
    end

    assign o_mosi = shift_reg[15];
    assign o_sclk = sclk_reg;

endmodule
