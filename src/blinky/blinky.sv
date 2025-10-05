module blinky (
    input  logic i_clk,
    output logic o_led
);

    logic [23:0] counter = 0;

    always_ff @(posedge i_clk) begin
        if (counter == 24'd49_999_999) begin
            counter <= 0;
            o_led <= ~o_led;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
