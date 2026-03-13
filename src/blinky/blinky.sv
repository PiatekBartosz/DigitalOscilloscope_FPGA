module blinky (
    input  logic i_clk,
    output logic o_led
);

    logic counter = 0;

    always_ff @(posedge i_clk) begin
        if (counter == 1) begin
            counter <= 0;
            o_led <= ~o_led;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
