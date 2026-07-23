`timescale 1ns/1ps

module tb_trigger_path;

    localparam int LAST_ADDR   = 15;
    localparam int PRETRIG_CNT = 4;

    bit verbose;

    logic i_clk = 0;
    logic i_rst_n = 0;

    always #5 i_clk = ~i_clk;

    initial begin
        if ($test$plusargs("WAVE")) begin
            $dumpfile("waves_trigger.vcd");
            $dumpvars(0, tb_trigger_path);
        end
        verbose = $test$plusargs("VERBOSE");
    end

    logic        i_trigg = 0;
    logic        r_trigger_en = 0;
    logic        r_capture_enable = 0;
    logic [12:0] r_pretrigger_count = 13'd0;
    logic        r_reset_fifo = 0;

    logic [13:0] w_mock_ch1, w_mock_ch2;
    logic        w_mock_valid;
    logic [13:0] w_decim_ch1, w_decim_ch2;
    logic        w_decim_valid;
    logic [13:0] w_buf_ch1, w_buf_ch2;
    logic        w_buf_valid;
    logic        w_batch_ready, w_overflow, w_sample_written, w_pretrigger_ready;
    logic        w_read_advance = 0;

    logic        w_trigg_rising, w_pretrigger_mode, w_trigger_fire;
    logic        w_trigger_accept, w_trigger_armed, w_gated_capture_enable;

    mock_gen #(
        .CLK_FREQ_HZ   (800),
        .SAMPLE_RATE_HZ(80)
    ) mock_inst (
        .i_clk     (i_clk),
        .i_rst_n   (i_rst_n),
        .i_enable  (1'b1),
        .i_advance (w_sample_written),
        .o_ch1_data(w_mock_ch1),
        .o_ch2_data(w_mock_ch2),
        .o_valid   (w_mock_valid)
    );

    decimator decim_inst (
        .i_clk     (i_clk),
        .i_rst_n   (i_rst_n),
        .i_factor  (11'd0),
        .i_ch1_data(w_mock_ch1),
        .i_ch2_data(w_mock_ch2),
        .i_valid   (w_mock_valid),
        .i_resync  (w_trigger_accept),
        .o_ch1_data(w_decim_ch1),
        .o_ch2_data(w_decim_ch2),
        .o_valid   (w_decim_valid)
    );

    trigger_ctrl glue_inst (
        .i_clk                (i_clk),
        .i_rst_n              (i_rst_n),
        .i_trigg               (i_trigg),
        .i_trigger_en          (r_trigger_en),
        .i_capture_enable      (r_capture_enable),
        .i_pretrigger_count    (r_pretrigger_count),
        .i_pretrigger_ready    (w_pretrigger_ready),
        .i_batch_ready         (w_batch_ready),
        .o_trigg_rising        (w_trigg_rising),
        .o_pretrigger_mode     (w_pretrigger_mode),
        .o_trigger_fire        (w_trigger_fire),
        .o_trigger_accept      (w_trigger_accept),
        .o_trigger_armed       (w_trigger_armed),
        .o_gated_capture_enable(w_gated_capture_enable)
    );

    sample_buffer buf_inst (
        .i_clk             (i_clk),
        .i_rst_n           (i_rst_n),
        .i_ch1_data        (w_decim_ch1),
        .i_ch2_data        (w_decim_ch2),
        .i_valid           (w_decim_valid),
        .i_capture_enable  (w_gated_capture_enable),
        .i_reset           (r_reset_fifo),
        .i_last_addr       (LAST_ADDR[12:0]),
        .i_pretrigger_mode (w_pretrigger_mode),
        .i_pretrigger_count(w_pretrigger_mode ? r_pretrigger_count : 13'd0),
        .i_trigger_fire    (w_trigger_fire),
        .o_ch1_data        (w_buf_ch1),
        .o_ch2_data        (w_buf_ch2),
        .o_valid           (w_buf_valid),
        .i_read_advance    (w_read_advance),
        .o_batch_ready     (w_batch_ready),
        .o_overflow        (w_overflow),
        .o_pretrigger_ready(w_pretrigger_ready),
        .o_sample_written  (w_sample_written)
    );

    task automatic do_reset();
        i_rst_n = 0;
        repeat (5) @(posedge i_clk);
        i_rst_n = 1;
        repeat (5) @(posedge i_clk);
    endtask

    task automatic soft_reset();
        @(posedge i_clk);
        r_reset_fifo = 1'b1;
        @(posedge i_clk);
        r_reset_fifo = 1'b0;
    endtask

    task automatic arm();
        r_trigger_en       = 1'b1;
        r_capture_enable   = 1'b1;
        r_pretrigger_count = PRETRIG_CNT[12:0];
    endtask

    task automatic pulse_trigger();
        @(posedge i_clk);
        i_trigg = 1'b1;
        repeat (3) @(posedge i_clk);
        i_trigg = 1'b0;
    endtask

    task automatic wait_cycles(int n);
        repeat (n) @(posedge i_clk);
    endtask

    task automatic wait_batch_ready(output bit got_ready, input int max_cycles);
        int i;
        got_ready = 1'b0;
        for (i = 0; i < max_cycles && !got_ready; i++) begin
            @(posedge i_clk);
            if (w_batch_ready) got_ready = 1'b1;
        end
    endtask

    logic [13:0] captured1[16];
    logic [13:0] captured2[16];
    int          read_idx;

    task automatic read_one();
        @(posedge i_clk);
        while (!w_buf_valid) @(posedge i_clk);
        captured1[read_idx] = w_buf_ch1;
        captured2[read_idx] = w_buf_ch2;
        @(posedge i_clk);
        w_read_advance = 1'b1;
        @(posedge i_clk);
        w_read_advance = 1'b0;
    endtask

    task automatic read_all();
        for (read_idx = 0; read_idx < 16; read_idx++) read_one();
    endtask

    task automatic check_capture(string name, logic [13:0] trig_value);
        for (int i = 1; i < 16; i++) begin
            if (captured1[i] !== (captured1[i-1] + 14'd2)) begin
                $error("[%s]: CH1 ramp broken at index %0d: %0d -> %0d",
                          name, i, captured1[i-1], captured1[i]);
                $fatal(1);
            end
            if (captured2[i] !== ~captured1[i]) begin
                $error("[%s]: CH2 mismatch at index %0d: expected ~%0d got %0d",
                          name, i, captured1[i], captured2[i]);
                $fatal(1);
            end
        end
        if (captured1[PRETRIG_CNT] !== trig_value) begin
            $error("[%s]: trigger sample expected at index %0d = %0d, got %0d",
                      name, PRETRIG_CNT, trig_value, captured1[PRETRIG_CNT]);
            $fatal(1);
        end
        if (verbose) begin
            $write("[%s] CH1:", name);
            for (int i = 0; i < 16; i++) $write(" %0d", captured1[i]);
            $display("  (trigger @ %0d)", PRETRIG_CNT);
        end
    endtask

    logic [13:0] trig_snapshot;
    always @(posedge w_trigger_accept) trig_snapshot = w_mock_ch1;

    initial begin
        bit ready;

        do_reset();

        arm();
        wait_batch_ready(ready, 2400);
        if (ready) begin
            $error("[A-no-signal]: batch_ready asserted with no i_trigg edge ever applied");
            $fatal(1);
        end else if (verbose) begin
            $display("[A-no-signal] OK: batch_ready never asserted, as expected");
        end

        soft_reset();
        pulse_trigger();
        wait_batch_ready(ready, 400);
        if (ready) begin
            $error("[B-early-edge]: batch_ready asserted before pretrigger history was valid");
            $fatal(1);
        end
        wait_cycles(40 * 10);
        pulse_trigger();

        wait_batch_ready(ready, 1200);
        if (!ready) begin
            $error("[B-real-edge]: batch_ready never asserted after a real i_trigg edge");
            $fatal(1);
        end else begin
            read_all();
            check_capture("B-real-edge", trig_snapshot);
        end

        $display("ALL SCENARIOS PASSED");

        $finish;
    end

    initial begin
        #500000;
        $error("testbench timed out");
        $fatal(1);
    end

endmodule
