/* sample_buffer.sv
 *
 * Behaviour
 * ---------
 *  FILLING   – ADC samples are written to two on-chip RAM banks (one per
 *               channel) via Port A.  The write pointer increments on every
 *               valid sample.  When location 8191 is written the state
 *               machine moves to the drain sequence and writing stops.
 *
 *  PREFETCH  – The read pointer is presented to Port B.  Port B has a
 *               registered output (outdata_reg_b = "CLOCK0"), so one clock
 *               cycle is needed before the data is valid.
 *
 *  LATCH     – q_b is stable.  The pair is captured into o_ch1/ch2_data and
 *               o_valid is asserted for exactly ONE cycle so that mcu_parallel
 *               fires exactly one IRQ per sample pair.
 *
 *  WAIT_READ – Data is held in the output registers.  The state machine waits
 *               for i_read_advance (pulsed by mcu_parallel when the MCU reads
 *               OP_CH2).  The read pointer then advances and the cycle repeats.
 *               After location 8191 is consumed writing is re-enabled.
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
    input  logic        i_clk,
    input  logic        i_rst_n,

    // ADC / mock data source (registered outputs from ltc2299 / mock_gen)
    input  logic [13:0] i_ch1_data,
    input  logic [13:0] i_ch2_data,
    input  logic        i_valid,
    input  logic        i_capture_enable,
    input  logic        i_reset,          // synchronous soft reset (from CTRL reg)

    // Pre-fetched sample output → mcu_parallel
    // o_valid is a single-cycle pulse; o_ch1/ch2_data hold until next pulse
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid,

    // Pulsed by mcu_parallel when MCU completes an OP_CH2 read transaction
    input  logic        i_read_advance,

    // Status flags → mcu_parallel STATUS register
    output logic        o_batch_ready,   // high while memory full / being drained
    output logic        o_overflow       // sample(s) lost during drain phase
);

    localparam integer DEPTH      = 8192;
    localparam integer ADDRW      = 13;
    localparam [12:0]  LAST_ADDR  = 13'd8191;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    localparam [1:0] ST_FILLING   = 2'd0;
    localparam [1:0] ST_PREFETCH  = 2'd1;
    localparam [1:0] ST_LATCH     = 2'd2;
    localparam [1:0] ST_WAIT_READ = 2'd3;

    logic [1:0] r_state;

    logic [ADDRW-1:0] r_wr_addr;
    logic [ADDRW-1:0] r_rd_addr;

    // Combinatorial write enable — asserted for exactly the cycle i_valid is
    // seen while filling.  All inputs are registered so setup timing is met.
    wire w_wr_en = (r_state == ST_FILLING) & i_valid & i_capture_enable;

    // -------------------------------------------------------------------------
    // Memory instances
    // -------------------------------------------------------------------------
    logic [15:0] w_q_ch1, w_q_ch2;

    memory mem_ch1 (
        .clock     (i_clk),
        // Port A – write (ADC)
        .address_a (r_wr_addr),
        .data_a    ({2'b00, i_ch1_data}),
        .wren_a    (w_wr_en),
        .q_a       (),
        // Port B – read (MCU pre-fetch)
        .address_b (r_rd_addr),
        .data_b    (16'd0),
        .wren_b    (1'b0),
        .q_b       (w_q_ch1)
    );

    memory mem_ch2 (
        .clock     (i_clk),
        .address_a (r_wr_addr),
        .data_a    ({2'b00, i_ch2_data}),
        .wren_a    (w_wr_en),
        .q_a       (),
        .address_b (r_rd_addr),
        .data_b    (16'd0),
        .wren_b    (1'b0),
        .q_b       (w_q_ch2)
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
                        if (r_wr_addr == LAST_ADDR) begin
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
                    // r_rd_addr is on address_b this cycle; registered output
                    // appears one cycle later in ST_LATCH.
                    r_state <= ST_LATCH;
                end

                ST_LATCH: begin
                    // q_b is valid now — capture and fire single-cycle valid
                    o_ch1_data <= w_q_ch1[13:0];
                    o_ch2_data <= w_q_ch2[13:0];
                    o_valid    <= 1'b1;
                    r_state    <= ST_WAIT_READ;
                end

                ST_WAIT_READ: begin
                    if (i_read_advance) begin
                        if (r_rd_addr == LAST_ADDR) begin
                            // All 8192 pairs delivered; re-enable writing
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

            // Mark overflow when ADC samples arrive while the memory is
            // occupied (ST_PREFETCH / ST_LATCH / ST_WAIT_READ).  Cleared on
            // the transition back to ST_FILLING so it reflects only the drain
            // interval just completed.
            if (r_state != ST_FILLING && i_valid && i_capture_enable) begin
                o_overflow <= 1'b1;
            end
        end
    end

endmodule
