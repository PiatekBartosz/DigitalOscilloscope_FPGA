module digital_oscilloscope (
    input logic i_clk_ext,
    input logic i_clk_devkit,
    input logic i_areset_n,

    output logic        o_adc_oe_a_n,
    output logic        o_adc_shdn_a,
    input  logic [13:0] i_adc_a,
    input  logic        i_adc_of_a,

    output logic        o_adc_oe_b_n,
    output logic        o_adc_shdn_b,
    input  logic [13:0] i_adc_b,
    input  logic        i_adc_of_b,

    output logic o_adc_mux,
    output logic o_clk_adc,

    // Bus_2_STM parallel interface – 14-bit bidirectional data bus
    inout  wire  [13:0] io_mcu_data,      // PE_dataBus: 14-bit bidirectional
    input  logic [ 2:0] i_mcu_addr,       // CFG_ADDR[2:0]
    input  logic        i_mcu_rw,         // C7_Write_To_FPGA: 1=write 0=read
    input  logic        i_mcu_req,        // C3_Trigger_Clock_INP: write strobe
    input  logic        i_mcu_inc,        // Increment: advance sample pointer
    output logic        o_mcu_req_echo,   // C3_Trigger_Clock_OUT
    output logic        o_mcu_busy,       // Status_FPGA_Busy

    output logic o_led
);

    assign o_clk_adc = i_clk_ext;

    logic [13:0] w_ch_a_data, w_ch_b_data;
    logic        w_ch_a_valid, w_ch_b_valid;
    logic        w_capture_enable, w_mock_enable, w_reset_fifo;
    logic        w_fifo_overflow, w_batch_ready;
    logic [13:0] w_mock_ch1, w_mock_ch2;
    logic        w_mock_valid;
    logic [13:0] w_adc_ch1, w_adc_ch2;
    logic        w_adc_valid;
    logic [13:0] w_buf_ch1, w_buf_ch2;
    logic        w_buf_valid;
    logic        w_read_advance;
    logic [12:0] w_sample_last_addr;
    logic        w_sample_written;

    assign w_adc_ch1   = w_mock_enable ? w_mock_ch1 : w_ch_a_data;
    assign w_adc_ch2   = w_mock_enable ? w_mock_ch2 : w_ch_b_data;
    assign w_adc_valid = w_mock_enable ? w_mock_valid : w_ch_a_valid;

    mcu_parallel_if mcu_bus ();

    // 14-bit bidirectional bus: FPGA tristates when MCU writes (rw=1),
    // drives the bus when MCU reads (rw=0, data_oe=1)
    assign io_mcu_data     = mcu_bus.data_oe ? mcu_bus.data_out : 14'bz;
    assign mcu_bus.data_in = io_mcu_data;

    assign mcu_bus.addr = i_mcu_addr;
    assign mcu_bus.rw   = i_mcu_rw;
    assign mcu_bus.req  = i_mcu_req;
    assign mcu_bus.inc  = i_mcu_inc;
    assign o_mcu_req_echo = mcu_bus.req_echo;
    assign o_mcu_busy     = mcu_bus.busy;

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
        .i_clk             (i_clk_ext),
        .i_rst_n           (i_areset_n),
        .i_ch1_data        (w_buf_ch1),
        .i_ch2_data        (w_buf_ch2),
        .i_ch1_valid       (w_buf_valid),
        .i_ch2_valid       (w_buf_valid),
        .i_fifo_overflow   (w_fifo_overflow),
        .i_batch_ready     (w_batch_ready),
        .i_sdram_busy      (1'b0),
        .o_capture_enable  (w_capture_enable),
        .o_mock_enable     (w_mock_enable),
        .o_reset_fifo      (w_reset_fifo),
        .o_read_advance    (w_read_advance),
        .o_sample_last_addr(w_sample_last_addr),
        .mcu               (mcu_bus.device)
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
        .i_read_advance  (w_read_advance),
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
