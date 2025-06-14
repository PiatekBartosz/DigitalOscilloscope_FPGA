module digital_oscilloscope (
    input  clk,
    output led
);

    blinky blinky_inst (
        .clk(clk),
        .led(led)
    );

endmodule
