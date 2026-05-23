module blinky #(
    parameter int INPUT_CLOCK_FREQUENCY_HZ = 80_000_000,
    parameter int PERIOD_S    = 2
) (
    input  logic i_clk,
    output logic o_led = 1'b0
);
    localparam int TOGGLE_LIMIT = (INPUT_CLOCK_FREQUENCY_HZ * PERIOD_S) / 2;

    logic [$clog2(TOGGLE_LIMIT)-1:0] r_cnt = '0;

    always_ff @(posedge i_clk) begin
        if (r_cnt >= (TOGGLE_LIMIT - 1)) begin
            r_cnt <= '0;
            o_led <= ~o_led;
        end else begin
            r_cnt <= r_cnt + 1'b1;
        end
    end

endmodule
