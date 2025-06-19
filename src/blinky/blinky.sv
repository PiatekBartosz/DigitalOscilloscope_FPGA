module blinky (
    input  logic clk,
    output logic led
);

    logic [23:0] counter = 0;

    always_ff @(posedge clk) begin
        if (counter == 24'd49_999_999) begin
            counter <= 0;
            led <= ~led;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
