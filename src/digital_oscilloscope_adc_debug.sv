module digital_oscilloscope_adc_debug (
    input  logic        i_clk_ext,
    input  logic        i_clk_devkit,
    input  logic        i_areset_n,

    output logic        o_clk_adc,

    output logic        o_adc_oe_shdn_a_n,
    output logic        o_adc_oe_shdn_b_n,

    input  logic [13:0] i_adc_a,
    input  logic [13:0] i_adc_b,
    input  logic        i_adc_ready,
    input  logic        i_adc_overflow,

    input  logic [ 2:0] i_mcu_addr,
    input  logic        i_mcu_rw,
    input  logic        i_mcu_req,
    input  logic        i_mcu_inc,

    inout  wire  [13:0] io_mcu_data,
    output wire         o_mcu_busy,

    output logic        o_led
);

    assign o_clk_adc          = i_clk_ext;
    assign o_adc_oe_shdn_a_n = 1'b0;
    assign o_adc_oe_shdn_b_n = 1'b0;
    assign io_mcu_data        = 14'bz;
    assign o_mcu_busy         = 1'bz;

    blinky #(
        .INPUT_CLOCK_FREQUENCY_HZ(80_000_000),
        .PERIOD_S(2)
    ) blinky_inst (
        .i_clk(i_clk_ext),
        .o_led(o_led)
    );

endmodule
