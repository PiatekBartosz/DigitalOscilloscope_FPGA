module digital_oscilloscope (
    input  clk_in_0,
    output led,
    output clk_out_0,
    output clk_out_1
);

blinky blinky_inst (
    .clk(clk_in_0),
    .led(led)
);

adc_clk adc_clk_inst (
	.areset(1'b0),
	.inclk0(clk_in_0),
	.c0(clk_out_0),
	.c1(clk_out_1),
	.locked(pll_locked)
);

endmodule
