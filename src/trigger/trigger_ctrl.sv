module trigger_ctrl (
    input logic i_clk,
    input logic i_rst_n,

    input logic        i_trigg,
    input logic        i_trigger_en,
    input logic        i_capture_enable,
    input logic [12:0] i_pretrigger_count,
    input logic        i_pretrigger_ready,
    input logic        i_batch_ready,

    output logic o_trigg_rising,
    output logic o_pretrigger_mode,
    output logic o_trigger_fire,
    output logic o_trigger_accept,
    output logic o_trigger_armed,
    output logic o_gated_capture_enable
);

    logic r_trigg_sync0, r_trigg_sync1, r_trigg_prev;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_trigg_sync0 <= 1'b0;
            r_trigg_sync1 <= 1'b0;
            r_trigg_prev  <= 1'b0;
        end else begin
            r_trigg_sync0 <= i_trigg;
            r_trigg_sync1 <= r_trigg_sync0;
            r_trigg_prev  <= r_trigg_sync1;
        end
    end
    assign o_trigg_rising = r_trigg_sync1 & ~r_trigg_prev;

    localparam [1:0] TRIG_IDLE = 2'd0, TRIG_ARMED = 2'd1, TRIG_CAPTURING = 2'd2;
    logic [1:0] r_trig_state;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_trig_state <= TRIG_IDLE;
        end else begin
            case (r_trig_state)
                TRIG_IDLE: begin
                    if (i_trigger_en && i_capture_enable) r_trig_state <= TRIG_ARMED;
                end
                TRIG_ARMED: begin
                    if (!i_trigger_en || !i_capture_enable) r_trig_state <= TRIG_IDLE;
                    else if (o_trigger_accept)
                        r_trig_state <= TRIG_CAPTURING;
                end
                TRIG_CAPTURING: begin
                    if (!i_trigger_en) r_trig_state <= TRIG_IDLE;
                    else if (i_batch_ready) r_trig_state <= TRIG_ARMED;
                end
                default: r_trig_state <= TRIG_IDLE;
            endcase
        end
    end

    assign o_pretrigger_mode = i_trigger_en & (i_pretrigger_count != 13'd0);

    assign o_trigger_accept = o_trigg_rising & i_trigger_en & i_capture_enable
                              & (!o_pretrigger_mode | i_pretrigger_ready);
    assign o_trigger_fire = o_trigger_accept & o_pretrigger_mode;
    assign o_trigger_armed = (r_trig_state == TRIG_ARMED);

    assign o_gated_capture_enable = o_pretrigger_mode
                                     ? i_capture_enable
                                     : (i_trigger_en
                                        ? (r_trig_state == TRIG_CAPTURING)
                                        : i_capture_enable);

endmodule
