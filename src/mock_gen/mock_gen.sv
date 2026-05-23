/* mock_gen.sv
 *
 * Generates a deterministic ramp pattern for memory-read/write testing.
 *
 * The 13-bit position counter r_sample maps exactly one full ramp period to
 * 2^13 = 8192 written samples:
 *
 *   CH1 data = {r_sample, 1'b0}  →  0, 2, 4, …, 16382  (14-bit ramp up)
 *   CH2 data = ~{r_sample, 1'b0} →  16383, …, 1         (14-bit ramp down)
 *
 * Key property: r_sample advances ONLY when i_advance is asserted, which is
 * driven by sample_buffer.o_sample_written (= w_wr_en).  This means the
 * counter idles during the MCU drain phase, so consecutive captures of fewer
 * than 8192 samples show perfectly contiguous segments of the ramp with no
 * gap from drain-time sample loss:
 *
 *   sample_size=4096, capture 1 → samples 0..4095   (first half)
 *   sample_size=4096, capture 2 → samples 4096..8191 (second half)
 *   sample_size=4096, capture 3 → samples 0..4095   (repeats)
 *
 *   sample_size=8192, capture 1 → samples 0..8191   (full ramp, whole line)
 *
 * The counter is preserved across mock-enable/disable cycles so that re-
 * enabling mock_adc picks up where it left off.  Only a hardware reset
 * (i_rst_n) returns it to zero.
 */

module mock_gen #(
    parameter int CLK_FREQ_HZ    = 50_000_000,
    parameter int SAMPLE_RATE_HZ = 1_000
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic        i_enable,
    // Asserted for one cycle each time the last valid sample was accepted by
    // sample_buffer (o_sample_written from sample_buffer).  r_sample only
    // advances on accepted writes, keeping captures contiguous.
    input  logic        i_advance,
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid
);

    localparam int DIV   = CLK_FREQ_HZ / SAMPLE_RATE_HZ - 1;
    localparam int CNT_W = $clog2(DIV + 1);

    logic [CNT_W-1:0] r_div_cnt;
    logic [     12:0] r_sample;  // 13-bit; natural overflow wraps at 2^13 = 8192

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_div_cnt <= '0;
            r_sample  <= '0;
            o_valid   <= 1'b0;
        end else begin
            o_valid <= 1'b0;  // default: deassert each cycle

            // Advance position only when the previous valid sample was actually
            // written into sample_buffer (i_advance = o_sample_written).
            // o_valid here is the registered value from the previous cycle.
            if (o_valid && i_advance)
                r_sample <= r_sample + 13'd1;

            if (i_enable) begin
                if (r_div_cnt == CNT_W'(DIV)) begin
                    r_div_cnt <= '0;
                    o_valid   <= 1'b1;
                end else begin
                    r_div_cnt <= r_div_cnt + 1'b1;
                end
            end else begin
                r_div_cnt <= '0;
                // r_sample intentionally NOT reset: counter position persists
                // so that re-enabling mock picks up from the same point.
            end
        end
    end

    // Combinatorial outputs driven by r_sample (a registered flip-flop), so
    // they are stable and glitch-free at sample_buffer's input.
    assign o_ch1_data = {r_sample, 1'b0};
    assign o_ch2_data = ~{r_sample, 1'b0};

endmodule
