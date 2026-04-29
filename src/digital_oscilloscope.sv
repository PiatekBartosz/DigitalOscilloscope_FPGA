module digital_oscilloscope (
    input logic i_clk_ext,
    input logic i_clk_devkit,
    input logic i_areset_n,

    // LTC2299 Channel A
    output logic        o_adc_oe_a_n,
    output logic        o_adc_shdn_a,
    input  logic [13:0] i_adc_a,
    input  logic        i_adc_of_a,

    // LTC2299 Channel B
    output logic        o_adc_oe_b_n,
    output logic        o_adc_shdn_b,
    input  logic [13:0] i_adc_b,
    input  logic        i_adc_of_b,

    // LTC2299 shared
    output logic o_adc_mux,
    output logic o_clk_adc,

    // Parallel command interface to MCU
    input  logic [ 7:0] i_mcu_ctrl,  // [2:0]=OP, [7:3]=PAYLOAD
    input  logic        i_mcu_rw,    // 0=write, 1=read
    input  logic        i_mcu_req,
    output logic [13:0] o_mcu_data,  // result driven to MCU on reads
    output logic        o_mcu_ack,
    output logic        o_mcu_irq,

    output logic o_led
);

    logic        pll_clk;
    logic        pll_locked;
    logic        s_rst_n;
    logic [13:0] s_ch_a_data;
    logic [13:0] s_ch_b_data;
    logic        s_ch_a_valid;
    logic        s_ch_b_valid;
    logic        s_capture_enable;
    logic        s_mock_enable;

    // TODO: connect when FIFO/SDRAM fabric is added
    logic        s_fifo_overflow = 1'b0;
    logic        s_batch_ready = 1'b0;
    logic        s_sdram_busy = 1'b0;

    logic [13:0] s_mock_ch1;
    logic [13:0] s_mock_ch2;
    logic        s_mock_valid;

    // Hold reset until PLL is locked and the external reset is de-asserted
    assign s_rst_n = pll_locked & i_areset_n;

    mock_gen #(
        .CLK_FREQ_HZ   (50_000_000),
        .SAMPLE_RATE_HZ(1_000)
    ) mock_inst (
        .i_clk     (pll_clk),
        .i_rst_n   (s_rst_n),
        .i_enable  (s_mock_enable),
        .o_ch1_data(s_mock_ch1),
        .o_ch2_data(s_mock_ch2),
        .o_valid   (s_mock_valid)
    );

    logic [13:0] s_plink_ch1;
    logic [13:0] s_plink_ch2;
    logic        s_plink_valid;

    assign s_plink_ch1   = s_mock_enable ? s_mock_ch1 : s_ch_a_data;
    assign s_plink_ch2   = s_mock_enable ? s_mock_ch2 : s_ch_b_data;
    assign s_plink_valid = s_mock_enable ? s_mock_valid : s_ch_a_valid;

    adc_clk adc_clk_inst (
        .areset(1'b0),
        .inclk0(i_clk_devkit),
        .c0    (pll_clk),
        .locked(pll_locked)
    );

    assign o_clk_adc = pll_clk;

    mcu_parallel_if mcu_bus ();

    assign mcu_bus.ctrl = i_mcu_ctrl;
    assign mcu_bus.rw   = i_mcu_rw;
    assign mcu_bus.req  = i_mcu_req;
    assign o_mcu_data   = mcu_bus.data;
    assign o_mcu_ack    = mcu_bus.ack;
    assign o_mcu_irq    = mcu_bus.irq;

    mcu_parallel parallel_inst (
        .i_clk           (pll_clk),
        .i_rst_n         (s_rst_n),
        .i_ch1_data      (s_plink_ch1),
        .i_ch2_data      (s_plink_ch2),
        .i_ch1_valid     (s_plink_valid),
        .i_ch2_valid     (s_plink_valid),
        .i_fifo_overflow (s_fifo_overflow),
        .i_batch_ready   (s_batch_ready),
        .i_sdram_busy    (s_sdram_busy),
        .o_capture_enable(s_capture_enable),
        .o_mock_enable   (s_mock_enable),
        .o_reset_fifo    (),
        .o_sample_count  (),
        .o_frequency     (),
        .mcu             (mcu_bus.device)
    );

    ltc2299 #(
        .NAP_RECOVERY_CYCLES(100)
    ) adc_inst (
        .i_clk       (pll_clk),
        .i_rst_n     (s_rst_n),
        .i_enable_a  (s_capture_enable & ~s_mock_enable),
        .i_enable_b  (s_capture_enable & ~s_mock_enable),
        .o_oe_a_n    (o_adc_oe_a_n),
        .o_oe_b_n    (o_adc_oe_b_n),
        .o_shdn_a    (o_adc_shdn_a),
        .o_shdn_b    (o_adc_shdn_b),
        .o_mux       (o_adc_mux),
        .i_da        (i_adc_a),
        .i_of_a      (i_adc_of_a),
        .i_db        (i_adc_b),
        .i_of_b      (i_adc_of_b),
        .o_data_a    (s_ch_a_data),
        .o_overflow_a(),
        .o_data_b    (s_ch_b_data),
        .o_overflow_b(),
        .o_valid_a   (s_ch_a_valid),
        .o_valid_b   (s_ch_b_valid)
    );

    blinky #(
        .INPUT_CLOCK_FREQUENCY_HZ(50_000_000),
        .PERIOD_S(2)
    ) blinky_inst (
        .i_clk(i_clk_devkit),
        .o_led(o_led)
    );

endmodule
