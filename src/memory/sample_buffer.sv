/* sample_buffer.sv
 *
 * Behaviour
 * ---------
 *  FILLING   – ADC samples are written to two on-chip RAM banks (one per
 *               channel) via Port A.  The write pointer increments on every
 *               valid sample.  When i_last_addr is reached the state machine
 *               moves to the drain sequence and writing stops.
 *
 *  PREFETCH  – The read pointer is presented to Port B.  Port B has both
 *               address_reg_b = "CLOCK0" and outdata_reg_b = "CLOCK0", giving
 *               2-cycle latency.  Two states (PREFETCH + PREFETCH2) are used
 *               before LATCH so that q_b is valid when captured.
 *
 *  LATCH     – q_b is stable.  The pair is captured into o_ch1/ch2_data and
 *               o_valid is asserted for exactly ONE cycle so that mcu_parallel
 *               fires exactly one IRQ per sample pair.
 *
 *  WAIT_READ – Data is held in the output registers.  The state machine waits
 *               for i_read_advance (pulsed by mcu_parallel when the MCU reads
 *               OP_CH2).  The read pointer then advances and the cycle repeats.
 *               After i_last_addr is consumed writing is re-enabled.
 *
 * Port A write alignment
 * ----------------------
 *  i_ch1_data / i_ch2_data are registered flip-flop outputs from ltc2299 so
 *  they are stable at the rising edge.  r_wr_addr is also a flip-flop.
 *  w_wr_en is a combinatorial gate of flip-flop outputs (r_state, i_valid,
 *  i_capture_enable) so it is glitch-free and meets setup time at 50 MHz.
 *  This means the write: data[r_wr_addr] ← i_ch1_data happens in the same
 *  clock cycle that i_valid is observed, with no pipeline mismatch.
 */

module sample_buffer (
    input logic i_clk,
    input logic i_rst_n,

    // ADC / mock data source (registered outputs from ltc2299 / mock_gen)
    input logic [13:0] i_ch1_data,
    input logic [13:0] i_ch2_data,
    input logic        i_valid,
    input logic        i_capture_enable,
    input logic        i_reset,           // synchronous soft reset (from CTRL reg)

    // Configurable capture depth from mcu_parallel OP_SAMPLE_SIZE register.
    // Sampled at the moment the state machine re-enters ST_FILLING, so changes
    // take effect at the start of the next acquisition, never mid-capture.
    input logic [12:0] i_last_addr,

    // Pre-fetched sample output → mcu_parallel
    // o_valid is a single-cycle pulse; o_ch1/ch2_data hold until next pulse
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid,

    // Pulsed by mcu_parallel when MCU completes an OP_CH2 read transaction
    input logic i_read_advance,

    // Status flags → mcu_parallel STATUS register
    output logic o_batch_ready,    // high while memory full / being drained
    output logic o_overflow,       // sample(s) lost during drain phase

    // Pulsed for one cycle each time a sample pair is committed to RAM.
    // Fed back to mock_gen.i_advance so its counter only ticks on real writes.
    output logic o_sample_written
);

    localparam integer DEPTH = 8192;
    localparam integer ADDRW = 13;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam [2:0] ST_FILLING   = 3'd0;
    localparam [2:0] ST_PREFETCH  = 3'd1;  // cycle 1: rdaddress registered by altsyncram
    localparam [2:0] ST_PREFETCH2 = 3'd2;  // cycle 2: memory data registered by outdata_reg_b
    localparam [2:0] ST_LATCH     = 3'd3;  // q_b is now valid — capture and assert o_valid
    localparam [2:0] ST_WAIT_READ = 3'd4;

    logic [      2:0] r_state;

    logic [ADDRW-1:0] r_wr_addr;
    logic [ADDRW-1:0] r_rd_addr;

    // Combinatorial write enable — asserted for exactly the cycle i_valid is
    // seen while filling.  All inputs are registered so setup timing is met.
    wire w_wr_en = (r_state == ST_FILLING) & i_valid & i_capture_enable;

    assign o_sample_written = w_wr_en;

    // -------------------------------------------------------------------------
    // Memory instances
    // -------------------------------------------------------------------------
    logic [13:0] w_q_ch1, w_q_ch2;

    memory mem_ch1 (
        .clock    (i_clk),
        .data     (i_ch1_data),
        .rdaddress(r_rd_addr),
        .wraddress(r_wr_addr),
        .wren     (w_wr_en),
        .q        (w_q_ch1)
    );

    memory mem_ch2 (
        .clock    (i_clk),
        .data     (i_ch2_data),
        .rdaddress(r_rd_addr),
        .wraddress(r_wr_addr),
        .wren     (w_wr_en),
        .q        (w_q_ch2)
    );

    // -------------------------------------------------------------------------
    // Control state machine
    // -------------------------------------------------------------------------
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state       <= ST_FILLING;
            r_wr_addr     <= '0;
            r_rd_addr     <= '0;
            o_ch1_data    <= '0;
            o_ch2_data    <= '0;
            o_valid       <= 1'b0;
            o_batch_ready <= 1'b0;
            o_overflow    <= 1'b0;
        end else if (i_reset) begin
            r_state       <= ST_FILLING;
            r_wr_addr     <= '0;
            r_rd_addr     <= '0;
            o_ch1_data    <= '0;
            o_ch2_data    <= '0;
            o_valid       <= 1'b0;
            o_batch_ready <= 1'b0;
            o_overflow    <= 1'b0;
        end else begin
            o_valid <= 1'b0;  // default: deassert each cycle

            case (r_state)

                ST_FILLING: begin
                    if (w_wr_en) begin
                        if (r_wr_addr == i_last_addr) begin
                            // Memory full after this write; switch to drain
                            r_wr_addr     <= '0;
                            r_rd_addr     <= '0;
                            o_batch_ready <= 1'b1;
                            o_overflow    <= 1'b0;
                            r_state       <= ST_PREFETCH;
                        end else begin
                            r_wr_addr <= r_wr_addr + 1'b1;
                        end
                    end
                end

                ST_PREFETCH: begin
                    // Cycle 1 of 2: r_rd_addr drives rdaddress; altsyncram
                    // address_reg_b captures it on the next clock edge.
                    r_state <= ST_PREFETCH2;
                end

                ST_PREFETCH2: begin
                    // Cycle 2 of 2: altsyncram's outdata_reg_b captures
                    // memory[r_rd_addr]; q_b is valid on the NEXT clock edge.
                    r_state <= ST_LATCH;
                end

                ST_LATCH: begin
                    // Memory read output is valid now — capture and fire single-cycle valid
                    o_ch1_data <= w_q_ch1;
                    o_ch2_data <= w_q_ch2;
                    o_valid    <= 1'b1;
                    r_state    <= ST_WAIT_READ;
                end

                ST_WAIT_READ: begin
                    if (i_read_advance) begin
                        if (r_rd_addr == i_last_addr) begin
                            // All pairs delivered; re-enable writing
                            r_rd_addr     <= '0;
                            r_wr_addr     <= '0;
                            o_batch_ready <= 1'b0;
                            r_state       <= ST_FILLING;
                        end else begin
                            r_rd_addr <= r_rd_addr + 1'b1;
                            r_state   <= ST_PREFETCH;
                        end
                    end
                end

                default: r_state <= ST_FILLING;
            endcase

            // Mark overflow when ADC samples arrive while memory is occupied.
            // Cleared on the transition back to ST_FILLING.
            if (r_state != ST_FILLING && i_valid && i_capture_enable) begin
                o_overflow <= 1'b1;
            end
        end
    end

endmodule
