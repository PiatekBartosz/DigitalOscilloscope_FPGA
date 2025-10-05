module digital_oscilloscope (
    input  i_clk,
    input i_areset_n,
    output o_led,
    output o_clk_0,
    output o_clk_1
);

//TODO: change later
assign i_reset_n = 0;

fpga_control u_fpga_control (
    .i_clk(i_clk),
    .i_areset_n(i_areset_n),

    //TODO: add reset of the signals

    // Bus interface
    .i_write_en(1'b0),
    .i_read_en(1'b0),
    .i_addr(1'b0),
    .i_write_data(1'b0),
    .o_read_data(),

    // Control
    .o_caputure_enable(),
    .o_mock_enable(),
    .o_reset_fifo(),

    // Status
    .i_fifo_overflow(1'b1),
    .i_batch_ready(1'b1),
    .i_sdram_busy(1'b1)

);

blinky u_blinky (
    .i_clk(i_clk),
    .o_led(o_led)
);

adc_clk u_adc_clk (
	.areset(1'b0),
	.inclk0(i_clk),
	.c0(o_clk_0),
	.c1(o_clk_1),
	.locked(pll_locked)
);

endmodule
