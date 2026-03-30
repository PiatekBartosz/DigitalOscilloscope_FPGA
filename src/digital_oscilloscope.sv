module digital_oscilloscope (
    input  logic i_clk_ext,
    output logic o_clk_adc,

    input  logic [13:0] i_adc_a,
    output logic o_adc_output_enable_a,

    output logic o_mcu_sclk,          
    output logic o_mcu_mosi,          
    output logic o_mcu_cs_n,          

    input  logic i_areset_n,
    input  logic i_clk_devkit,
    output logic o_led
);

    logic pll_clk;
    logic [13:0] s_adc_val;

    adc_clk adc_clk_inst (
        .areset (1'b0),
        .inclk0 (i_clk_ext),
        .c0     (pll_clk),
        .locked ()
    );

    assign o_clk_adc = pll_clk;

    adc_reader adc_inst (
        .i_clk      (pll_clk),
        .i_adc_pins (i_adc_a),
        .o_adc_oe_n (o_adc_output_enable_a),
        .o_adc_data (s_adc_val)
    );

    spi_master_tx #(
        .CLK_IN_HZ(80_000_000), 
        .TARGET_SPI_HZ(10_000_000) 
    ) u_spi_to_mcu (
        .i_clk  (pll_clk),
        .i_data (s_adc_val),
        .o_sclk (o_mcu_sclk),
        .o_mosi (o_mcu_mosi),
        .o_cs_n (o_mcu_cs_n)
    );

    blinky #(
        .INPUT_CLOCK_FREQUENCY_HZ(50_000_000), 
        .PERIOD_S(2)
    ) blinky_inst (
        .i_clk(i_clk_devkit), 
        .o_led(o_led)
    );

endmodule