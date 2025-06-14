module blinky (
    input  logic clk,
    output logic led
);

    logic [23:0] counter;

    always_ff @(posedge clk) begin
        if (counter == 50_000_000 - 1) begin
            counter <= 0;
            led <= ~led;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
