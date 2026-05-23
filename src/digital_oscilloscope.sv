module digital_oscilloscope (
    input logic i_clk_ext,
    input logic i_clk_devkit, // Unused right now
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

    output logic o_led
);

    assign o_clk_adc = i_clk_ext;

    logic [13:0] w_ch_a_data;
    logic [13:0] w_ch_b_data;
    logic        w_ch_a_valid;
    logic        w_ch_b_valid;
    logic        w_capture_enable;
    logic        w_mock_enable;
    logic        w_reset_fifo;

    logic        w_fifo_overflow;
    logic        w_batch_ready;

    logic [13:0] w_mock_ch1;
    logic [13:0] w_mock_ch2;
    logic        w_mock_valid;

    // Mux: live ADC vs synthetic mock data
    logic [13:0] w_adc_ch1, w_adc_ch2;
    logic        w_adc_valid;

    assign w_adc_ch1   = w_mock_enable ? w_mock_ch1 : w_ch_a_data;
    assign w_adc_ch2   = w_mock_enable ? w_mock_ch2 : w_ch_b_data;
    assign w_adc_valid = w_mock_enable ? w_mock_valid : w_ch_a_valid;

    // sample_buffer outputs (pre-fetched samples fed to mcu_parallel)
    logic [13:0] w_buf_ch1, w_buf_ch2;
    logic        w_buf_valid;
    logic        w_ch2_read_strobe;
    logic [12:0] w_sample_last_addr;
    // Pulsed when a sample pair is committed to RAM; fed back to mock_gen so
    // its counter only ticks on accepted writes (no drift during MCU drain).
    logic        w_sample_written;

    mcu_parallel_if mcu_bus ();

    assign mcu_bus.ctrl = i_mcu_ctrl;
    assign mcu_bus.rw   = i_mcu_rw;
    assign mcu_bus.req  = i_mcu_req;
    assign o_mcu_data   = mcu_bus.data;
    assign o_mcu_ack    = mcu_bus.ack;

    mock_gen #(
        .CLK_FREQ_HZ   (80_000_000),
        .SAMPLE_RATE_HZ(1_000)
    ) mock_inst (
        .i_clk     (i_clk_ext),
        .i_rst_n   (i_areset_n),
        .i_enable  (w_mock_enable),
        .i_advance (w_sample_written),
        .o_ch1_data(w_mock_ch1),
        .o_ch2_data(w_mock_ch2),
        .o_valid   (w_mock_valid)
    );

    mcu_parallel parallel_inst (
        .i_clk            (i_clk_ext),
        .i_rst_n          (i_areset_n),
        .i_ch1_data       (w_buf_ch1),
        .i_ch2_data       (w_buf_ch2),
        .i_ch1_valid      (w_buf_valid),
        .i_ch2_valid      (w_buf_valid),
        .i_fifo_overflow  (w_fifo_overflow),
        .i_batch_ready    (w_batch_ready),
        .i_sdram_busy     (1'b0),
        .o_capture_enable   (w_capture_enable),
        .o_mock_enable      (w_mock_enable),
        .o_reset_fifo       (w_reset_fifo),
        .o_ch2_read_strobe  (w_ch2_read_strobe),
        .o_sample_last_addr (w_sample_last_addr),
        .mcu                (mcu_bus.device)
    );

    sample_buffer buf_inst (
        .i_clk           (i_clk_ext),
        .i_rst_n         (i_areset_n),
        .i_ch1_data      (w_adc_ch1),
        .i_ch2_data      (w_adc_ch2),
        .i_valid         (w_adc_valid),
        .i_capture_enable(w_capture_enable),
        .i_reset         (w_reset_fifo),
        .i_last_addr     (w_sample_last_addr),
        .o_ch1_data      (w_buf_ch1),
        .o_ch2_data      (w_buf_ch2),
        .o_valid         (w_buf_valid),
        .i_read_advance  (w_ch2_read_strobe),
        .o_batch_ready   (w_batch_ready),
        .o_overflow      (w_fifo_overflow),
        .o_sample_written(w_sample_written)
    );

    ltc2299 #(
        .NAP_RECOVERY_CYCLES(100)
    ) adc_inst (
        .i_clk       (i_clk_ext),
        .i_rst_n     (i_areset_n),
        .i_enable_a  (w_capture_enable & ~w_mock_enable),
        .i_enable_b  (w_capture_enable & ~w_mock_enable),
        .o_oe_a_n    (o_adc_oe_a_n),
        .o_oe_b_n    (o_adc_oe_b_n),
        .o_shdn_a    (o_adc_shdn_a),
        .o_shdn_b    (o_adc_shdn_b),
        .o_mux       (o_adc_mux),
        .i_da        (i_adc_a),
        .i_of_a      (i_adc_of_a),
        .i_db        (i_adc_b),
        .i_of_b      (i_adc_of_b),
        .o_data_a    (w_ch_a_data),
        .o_overflow_a(),
        .o_data_b    (w_ch_b_data),
        .o_overflow_b(),
        .o_valid_a   (w_ch_a_valid),
        .o_valid_b   (w_ch_b_valid)
    );

    blinky #(
        .INPUT_CLOCK_FREQUENCY_HZ(80_000_000),
        .PERIOD_S(2)
    ) blinky_inst (
        .i_clk(i_clk_ext),
        .o_led(o_led)
    );

endmodule
