module sample_buffer (
    input logic i_clk,
    input logic i_rst_n,

    input logic [13:0] i_ch1_data,
    input logic [13:0] i_ch2_data,
    input logic        i_valid,
    input logic        i_capture_enable,
    input logic        i_reset,

    input logic [12:0] i_last_addr,

    input logic        i_pretrigger_mode,
    input logic [12:0] i_pretrigger_count,
    input logic        i_trigger_fire,

    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid,

    input logic i_read_advance,

    output logic o_batch_ready,
    output logic o_overflow,
    output logic o_pretrigger_ready,

    output logic o_sample_written
);

    localparam integer DEPTH = 8192;
    localparam integer ADDRW = 13;

    typedef enum logic [2:0] {
        ST_FILLING   = 3'd0,
        ST_PREFETCH  = 3'd1,
        ST_PREFETCH2 = 3'd2,
        ST_LATCH     = 3'd3,
        ST_WAIT_READ = 3'd4
    } buffer_state_t;

    buffer_state_t r_state;

    logic [ADDRW-1:0] r_wr_addr;
    logic [ADDRW-1:0] r_rd_addr;
    logic [ADDRW-1:0] r_read_count;

    logic             r_triggered;
    logic [ADDRW-1:0] r_trig_addr;
    logic [ADDRW-1:0] r_post_remaining;
    logic [ADDRW-1:0] r_pretrigger_fill_count;

    wire  [ADDRW-1:0] w_wr_addr_incr = (r_wr_addr == i_last_addr) ? '0 : (r_wr_addr + 1'b1);
    wire  [ADDRW-1:0] w_wr_addr_next = w_wr_en ? w_wr_addr_incr : r_wr_addr;

    wire              w_wr_en = (r_state == ST_FILLING) & i_valid & i_capture_enable;

    assign o_sample_written = w_wr_en;
    assign o_pretrigger_ready = i_pretrigger_mode
                                & (r_pretrigger_fill_count >= i_pretrigger_count);

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

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state          <= ST_FILLING;
            r_wr_addr        <= '0;
            r_rd_addr        <= '0;
            r_read_count     <= '0;
            r_triggered      <= 1'b0;
            r_trig_addr      <= '0;
            r_post_remaining <= '0;
            r_pretrigger_fill_count <= '0;
            o_ch1_data       <= '0;
            o_ch2_data       <= '0;
            o_valid          <= 1'b0;
            o_batch_ready    <= 1'b0;
            o_overflow       <= 1'b0;
        end else if (i_reset) begin
            r_state          <= ST_FILLING;
            r_wr_addr        <= '0;
            r_rd_addr        <= '0;
            r_read_count     <= '0;
            r_triggered      <= 1'b0;
            r_trig_addr      <= '0;
            r_post_remaining <= '0;
            r_pretrigger_fill_count <= '0;
            o_ch1_data       <= '0;
            o_ch2_data       <= '0;
            o_valid          <= 1'b0;
            o_batch_ready    <= 1'b0;
            o_overflow       <= 1'b0;
        end else begin
            o_valid <= 1'b0;

            case (r_state)

                ST_FILLING: begin
                    if (i_pretrigger_mode) begin
                        if (w_wr_en) begin
                            r_wr_addr <= w_wr_addr_next;
                            if (!r_triggered
                                && r_pretrigger_fill_count < i_pretrigger_count) begin
                                r_pretrigger_fill_count <= r_pretrigger_fill_count + 1'b1;
                            end
                        end

                        if (i_trigger_fire && !r_triggered) begin
                            r_triggered      <= 1'b1;
                            r_trig_addr      <= w_wr_addr_next;
                            r_post_remaining <= i_last_addr - i_pretrigger_count;
                        end else if (r_triggered && w_wr_en) begin
                            if (r_post_remaining == '0) begin
                                r_rd_addr        <= (r_trig_addr >= i_pretrigger_count)
                                                    ? (r_trig_addr - i_pretrigger_count)
                                                    : (r_trig_addr - i_pretrigger_count
                                                       + i_last_addr + 1'b1);
                                r_read_count <= '0;
                                o_batch_ready <= 1'b1;
                                o_overflow <= 1'b0;
                                r_triggered <= 1'b0;
                                r_state <= ST_PREFETCH;
                            end else begin
                                r_post_remaining <= r_post_remaining - 1'b1;
                            end
                        end
                    end else begin
                        r_pretrigger_fill_count <= '0;
                        if (w_wr_en) begin
                            if (r_wr_addr == i_last_addr) begin
                                r_wr_addr     <= '0;
                                r_rd_addr     <= '0;
                                r_read_count  <= '0;
                                o_batch_ready <= 1'b1;
                                o_overflow    <= 1'b0;
                                r_state       <= ST_PREFETCH;
                            end else begin
                                r_wr_addr <= r_wr_addr + 1'b1;
                            end
                        end
                    end
                end

                ST_PREFETCH: begin
                    r_state <= ST_PREFETCH2;
                end

                ST_PREFETCH2: begin
                    r_state <= ST_LATCH;
                end

                ST_LATCH: begin
                    o_ch1_data <= w_q_ch1;
                    o_ch2_data <= w_q_ch2;
                    o_valid    <= 1'b1;
                    r_state    <= ST_WAIT_READ;
                end

                ST_WAIT_READ: begin
                    if (i_read_advance) begin
                        if (r_read_count == i_last_addr) begin
                            r_rd_addr     <= '0;
                            r_wr_addr     <= '0;
                            r_pretrigger_fill_count <= '0;
                            o_batch_ready <= 1'b0;
                            r_state       <= ST_FILLING;
                        end else begin
                            r_rd_addr    <= (r_rd_addr == i_last_addr) ? '0 : (r_rd_addr + 1'b1);
                            r_read_count <= r_read_count + 1'b1;
                            r_state      <= ST_PREFETCH;
                        end
                    end
                end

                default: r_state <= ST_FILLING;
            endcase

            if (r_state != ST_FILLING && i_valid && i_capture_enable) begin
                o_overflow <= 1'b1;
            end
        end
    end

endmodule
