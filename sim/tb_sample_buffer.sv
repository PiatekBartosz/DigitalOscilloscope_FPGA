`timescale 1ns/1ps

module tb_sample_buffer;

    localparam int LAST_ADDR   = 15;
    localparam int PRETRIG_CNT = 4;

    logic        i_clk = 0;
    logic        i_rst_n = 0;
    logic [13:0] i_ch1_data, i_ch2_data;
    logic        i_valid = 0;
    logic        i_capture_enable = 1;
    logic        i_reset = 0;
    logic [12:0] i_last_addr = LAST_ADDR;
    logic        i_pretrigger_mode = 1;
    logic [12:0] i_pretrigger_count = PRETRIG_CNT;
    logic        i_trigger_fire = 0;
    logic [13:0] o_ch1_data, o_ch2_data;
    logic        o_valid;
    logic        i_read_advance = 0;
    logic        o_batch_ready;
    logic        o_overflow;
    logic        o_sample_written;

    int expected;
    bit verbose;

    initial begin
        if ($test$plusargs("WAVE")) begin
            $dumpfile("waves.vcd");
            $dumpvars(0, tb_sample_buffer);
        end
        verbose = $test$plusargs("VERBOSE");
    end

    sample_buffer dut (
        .i_clk             (i_clk),
        .i_rst_n           (i_rst_n),
        .i_ch1_data        (i_ch1_data),
        .i_ch2_data        (i_ch2_data),
        .i_valid           (i_valid),
        .i_capture_enable  (i_capture_enable),
        .i_reset           (i_reset),
        .i_last_addr       (i_last_addr),
        .i_pretrigger_mode (i_pretrigger_mode),
        .i_pretrigger_count(i_pretrigger_count),
        .i_trigger_fire    (i_trigger_fire),
        .o_ch1_data        (o_ch1_data),
        .o_ch2_data        (o_ch2_data),
        .o_valid           (o_valid),
        .i_read_advance    (i_read_advance),
        .o_batch_ready     (o_batch_ready),
        .o_overflow        (o_overflow),
        .o_sample_written  (o_sample_written)
    );

    always #5 i_clk = ~i_clk;

    task automatic do_write(int value);
        @(posedge i_clk);
        i_ch1_data = value[13:0];
        i_ch2_data = ~value[13:0];
        i_valid    = 1;
        @(posedge i_clk);
        i_valid    = 0;
    endtask

    task automatic do_write_with_trigger(int value);
        @(posedge i_clk);
        i_ch1_data     = value[13:0];
        i_ch2_data     = ~value[13:0];
        i_valid        = 1;
        i_trigger_fire = 1;
        @(posedge i_clk);
        i_valid        = 0;
        i_trigger_fire = 0;
    endtask

    task automatic do_idle_cycle();
        @(posedge i_clk);
    endtask

    task automatic fire_trigger_idle();
        do_idle_cycle();
        i_trigger_fire = 1;
        @(posedge i_clk);
        i_trigger_fire = 0;
    endtask

    task automatic do_reset();
        i_rst_n = 0;
        repeat (3) @(posedge i_clk);
        i_rst_n = 1;
        repeat (2) @(posedge i_clk);
    endtask

    task automatic do_soft_reset();
        @(posedge i_clk);
        i_reset = 1;
        @(posedge i_clk);
        i_reset = 0;
    endtask

    task automatic check_state_filling(string name);
        #1;
        if (dut.r_state !== dut.ST_FILLING) begin
            $error("[%s]: expected ST_FILLING, dut.r_state=%0d", name, dut.r_state);
            $fatal(1);
        end
        if (dut.r_wr_addr !== '0 || dut.r_rd_addr !== '0) begin
            $error("[%s]: expected wr_addr/rd_addr=0, got %0d/%0d",
                      name, dut.r_wr_addr, dut.r_rd_addr);
            $fatal(1);
        end
        if (o_batch_ready !== 1'b0) begin
            $error("[%s]: o_batch_ready still asserted", name);
            $fatal(1);
        end
    endtask

    logic [13:0] captured[16];
    logic [13:0] captured2[16];
    int          read_idx;

    task automatic read_one();
        @(posedge i_clk);
        while (!o_valid) @(posedge i_clk);
        captured[read_idx]  = o_ch1_data;
        captured2[read_idx] = o_ch2_data;
        @(posedge i_clk);
        i_read_advance = 1;
        @(posedge i_clk);
        i_read_advance = 0;
    endtask

    task automatic read_all();
        for (read_idx = 0; read_idx < 16; read_idx++) read_one();
    endtask

    task automatic wait_batch_ready(string name);
        #1;
        if (!o_batch_ready) begin
            $error("[%s]: o_batch_ready did not assert after fill", name);
            $fatal(1);
        end
    endtask

    task automatic wait_batch_drained(string name);
        #1;
        if (o_batch_ready) begin
            $error("[%s]: o_batch_ready still asserted after draining", name);
            $fatal(1);
        end
    endtask

    task automatic check_sequence(string name, int first_value, int trig_pos, int trig_value);
        for (int i = 0; i < 16; i++) begin
            expected = first_value + i;
            if (captured[i] !== expected[13:0]) begin
                $error("[%s]: CH1 position %0d expected %0d got %0d", name, i, expected, captured[i]);
                $fatal(1);
            end
            if (captured2[i] !== ~expected[13:0]) begin
                $error("[%s]: CH2 position %0d expected %0d got %0d",
                          name, i, ~expected[13:0], captured2[i]);
                $fatal(1);
            end
        end
        if (captured[trig_pos] !== trig_value[13:0]) begin
            $error("[%s]: trigger sample (position %0d) expected %0d got %0d",
                      name, trig_pos, trig_value, captured[trig_pos]);
            $fatal(1);
        end
        if (verbose) begin
            $write("[%s] Captured CH1 sequence:", name);
            for (int i = 0; i < 16; i++) $write(" %0d", captured[i]);
            $display("");
        end
    endtask

    task automatic run_pretrigger_cycle(string name, int base, int n_arm, int pretrig_cnt);
        i_pretrigger_mode  = 1;
        i_pretrigger_count = pretrig_cnt;
        for (int i = 0; i < n_arm; i++) do_write(base + i);
        fire_trigger_idle();
        for (int i = n_arm; i < n_arm + (LAST_ADDR + 1 - pretrig_cnt); i++) do_write(base + i);
        wait_batch_ready(name);
        read_all();
        wait_batch_drained(name);
        check_sequence(name, base + n_arm - pretrig_cnt, pretrig_cnt, base + n_arm);
    endtask

    initial begin
        do_reset();
        run_pretrigger_cycle("S1-idle-fire", 0, 50, PRETRIG_CNT);

        do_reset();
        i_pretrigger_mode  = 1;
        i_pretrigger_count = PRETRIG_CNT;
        for (int i = 0; i < 50; i++) do_write(i);
        do_write_with_trigger(50);
        for (int i = 51; i < 63; i++) do_write(i);
        wait_batch_ready("S2-coincident-fire");
        read_all();
        wait_batch_drained("S2-coincident-fire");
        check_sequence("S2-coincident-fire", 47, PRETRIG_CNT, 51);

        do_reset();
        i_pretrigger_mode  = 0;
        i_pretrigger_count = 0;
        for (int i = 100; i < 116; i++) do_write(i);
        wait_batch_ready("S3-legacy");
        read_all();
        wait_batch_drained("S3-legacy");
        check_sequence("S3-legacy", 100, 0, 100);

        do_reset();
        run_pretrigger_cycle("S4-max-pretrigger-clamp", 0, 20, LAST_ADDR);

        do_reset();
        run_pretrigger_cycle("S5a-back-to-back", 0, 20, PRETRIG_CNT);
        run_pretrigger_cycle("S5b-back-to-back", 200, 20, PRETRIG_CNT);

        do_reset();
        i_pretrigger_mode  = 0;
        i_pretrigger_count = 0;
        for (int i = 300; i < 316; i++) do_write(i);
        wait_batch_ready("S6-overflow");
        do_write(999);
        #1;
        if (!o_overflow) begin
            $error("[S6-overflow]: o_overflow did not assert for a write during drain");
            $fatal(1);
        end
        read_all();
        check_sequence("S6-overflow", 300, 0, 300);
        #1;
        if (!o_overflow) begin
            $error("[S6-overflow]: o_overflow unexpectedly cleared merely by returning to FILLING");
            $fatal(1);
        end
        for (int i = 400; i < 416; i++) do_write(i);
        #1;
        if (o_overflow) begin
            $error("[S6-overflow]: o_overflow did not clear at the start of the next batch");
            $fatal(1);
        end
        read_all();
        check_sequence("S6-overflow-round2", 400, 0, 400);

        do_reset();
        i_pretrigger_mode  = 1;
        i_pretrigger_count = PRETRIG_CNT;

        for (int i = 0; i < 10; i++) do_write(i);
        do_soft_reset();
        check_state_filling("S7a-reset-mid-arm");
        run_pretrigger_cycle("S7a-recovery", 0, 20, PRETRIG_CNT);

        i_pretrigger_mode  = 1;
        i_pretrigger_count = PRETRIG_CNT;
        for (int i = 0; i < 20; i++) do_write(i);
        fire_trigger_idle();
        for (int i = 20; i < 32; i++) do_write(i);
        wait_batch_ready("S7b-reset-mid-drain");
        for (read_idx = 0; read_idx < 5; read_idx++) read_one();
        do_soft_reset();
        check_state_filling("S7b-reset-mid-drain");
        run_pretrigger_cycle("S7b-recovery", 500, 20, PRETRIG_CNT);

        $display("ALL SCENARIOS PASSED");

        $finish;
    end

    initial begin
        #1000000;
        $error("testbench timed out");
        $fatal(1);
    end

endmodule
