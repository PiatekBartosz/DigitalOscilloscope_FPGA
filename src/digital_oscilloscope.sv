module digital_oscilloscope (
    input  logic i_clk_ext,
    output logic o_clk_adc,

    input logic [13:0] i_adc_a,
    output logic o_adc_output_enable_a,

    // Unused
    input  logic i_areset_n,
    input  logic i_clk_devkit,
    output logic o_led
);

    logic reset;
    logic pll_locked;

    logic pll_clk;

    assign reset = 1'b0;

    adc_clk adc_clk_inst (
        .areset (reset),
        .inclk0 (i_clk_ext),
        .c0     (pll_clk),
        .locked (pll_locked)
    );

    assign o_clk_adc = pll_clk;

    blinky #(
        .INPUT_CLOCK_FREQUENCY_HZ(50_000_000),
        .PERIOD_S(2)
    ) blinky_inst (
        .i_clk(i_clk_devkit),
        .o_led(o_led)
    );

endmodule
