// ADC debug gateware.
//
// Keeps the ADC clock and output-enable functional so the ADC runs normally.
// All FPGA→MCU drivers are tri-stated so the MCU bus does not interfere with
// manual probing of the ADC data lines.
//
// Build with:  make build_debug
// Program with:  make program_debug
module digital_oscilloscope_adc_debug (
    input  logic        i_clk_ext,
    input  logic        i_clk_devkit,
    input  logic        i_areset_n,

    // ADC clock - drives ADC directly from external oscillator
    output logic        o_clk_adc,

    // Combined OE+SHDN for each channel (active-low, PCB ties OE and SHDN
    // together).  Held low so both channels drive their data lines.
    output logic        o_adc_oe_shdn_a_n,
    output logic        o_adc_oe_shdn_b_n,

    // ADC data and status inputs (driven by ADC, FPGA only receives)
    input  logic [13:0] i_adc_a,
    input  logic [13:0] i_adc_b,
    input  logic        i_adc_ready,
    input  logic        i_adc_overflow,

    // MCU control inputs - accepted but ignored
    input  logic [ 2:0] i_mcu_addr,
    input  logic        i_mcu_rw,
    input  logic        i_mcu_req,
    input  logic        i_mcu_inc,

    // MCU data bus and busy line - both tri-stated so MCU cannot interfere
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
