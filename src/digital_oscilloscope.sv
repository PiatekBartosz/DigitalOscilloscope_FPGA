module digital_oscilloscope (
    input  logic i_clk_devkit,
    input  logic i_clk_ext,
    input  logic i_areset_n,
    output logic o_led,
    output logic o_clk_adc
);

logic pll_locked;

// Temporary internal reset (if needed)
// logic i_reset_n;

blinky u_blinky (
    .i_clk(i_clk_ext),
    .o_led(o_led)
);

adc_clk u_adc_clk (
    .areset(~i_areset_n),
    .inclk0(i_clk_ext),
    .c0(o_clk_adc),
    .c1(),
    .locked(pll_locked)
);

endmodule

// module digital_oscilloscope (
//     input  i_clk_devkit,
//     input  i_clk_ext,
//     input i_areset_n,
//     output o_led,
//     output o_clk_adc
// );

// //TODO: change later
// assign i_reset_n = 0;

// // fpga_control u_fpga_control (
// //     .i_clk(i_clk),
// //     .i_areset_n(i_areset_n),

// //     //TODO: add reset of the signals

// //     // Bus interface
// //     .i_write_en(1'b0),
// //     .i_read_en(1'b0),
// //     .i_addr(1'b0),
// //     .i_write_data(1'b0), 
// //     .o_read_data(),

// //     // Control
// //     .o_caputure_enable(),
// //     .o_mock_enable(),
// //     .o_reset_fifo(),

// //     // Status
// //     .i_fifo_overflow(1'b1),
// //     .i_batch_ready(1'b1),
// //     .i_sdram_busy(1'b1)

// // );

// // spi_control u_spi_control(
// // 		input  wire       stsinkvalid,   //   avalon_streaming_sink.valid|digital_oscilloscope|adc_clk:u_adc_clk|altpll:altpll_component

// // 		input  wire [7:0] stsinkdata,    //                        .data
// // 		output wire       stsinkready,   //                        .ready
// // 		input  wire       stsourceready, // avalon_streaming_source.ready
// // 		output wire       stsourcevalid, //                        .valid
// // 		output wire [7:0] stsourcedata,  //                        .data
// // 		input  wire       sysclk,        //              clock_sink.clk
// // 		input  wire       nreset,        //        clock_sink_reset.reset_n
// // 		input  wire       mosi,          //                export_0.mosi
// // 		input  wire       nss,           //                        .nss
// // 		inout  wire       miso,          //                        .miso
// // 		input  wire       sclk           //                        .sclk
// // );

// blinky u_blinky (
//     .i_clk(i_clk_ext),
//     .o_led(o_led)
// );

// adc_clk u_adc_clk (
// 	.areset(1'b0),
// 	.inclk0(i_clk_ext),
// 	.c0(o_clk_adc),
// 	.c1(),
// 	.locked(pll_locked)
// );

// endmodule
