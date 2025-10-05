module fpga_control #(
    parameter ADDR_SIZE = 4,
    parameter REG_SIZE  = 32,
    parameter DEFAULT_BATCH_SIZE = 1024
)(
    input  logic i_clk,
    input  logic i_areset_n,

    // Bus interface
    input  logic i_write_en,
    input  logic i_read_en,
    input  logic [ADDR_SIZE-1:0] i_addr,
    input  logic [REG_SIZE-1:0] i_write_data,
    output logic [REG_SIZE-1:0] o_read_data,

    // Control
    output logic o_capture_enable,
    output logic o_mock_enable,
    output logic o_reset_fifo,

    // Status
    input  logic i_fifo_overflow,
    input  logic i_batch_ready,
    input  logic i_sdram_busy
);

    typedef enum logic [ADDR_SIZE-1:0] {
        ADDR_CTRL         = ADDR_SIZE'(0),
        ADDR_STATUS       = ADDR_SIZE'(1),
        ADDR_OFFSET_GUARD = ADDR_SIZE'(2)
    } reg_addr_e;

    typedef enum logic [REG_SIZE-1:0] {
        CTRL_CAPTURE_ENABLE_OFFSET = REG_SIZE'(0),
        CTRL_MOCK_ENABLE_OFFSET    = REG_SIZE'(1),
        CTRL_RESET_FIFO_OFFSET     = REG_SIZE'(2),
        CTRL_OFFSET_GUARD          = REG_SIZE'(3)
    } reg_ctrl_field_offsets_e;

    typedef enum logic [REG_SIZE-1:0] {
        STATUS_FIFO_OVERFLOW_OFFSET = REG_SIZE'(0),
        STATUS_BATCH_READY_OFFSET   = REG_SIZE'(1),
        STATUS_SDRAM_BUSY_OFFSET    = REG_SIZE'(2),
        STATUS_OFFSET_GUARD         = REG_SIZE'(3)
    } reg_status_field_offsets_e;

    logic [REG_SIZE-1:0] r_control;
    logic [REG_SIZE-1:0] r_status;

    always_ff @(posedge i_clk or negedge i_areset_n) begin
        if (!i_areset_n) begin
            r_status  <= '0;
            r_control <= '0;
            o_capture_enable <= 1'b0;
            o_mock_enable    <= 1'b0;
            o_reset_fifo     <= 1'b0;
        end else begin
            r_status[1'd0] <= i_fifo_overflow;
            r_status[1'd1]   <= i_batch_ready;
            r_status[1'd2]    <= i_sdram_busy;
            r_status[REG_SIZE-1:1'd3] <= '0;

            o_capture_enable <= r_control[1'd0];
            o_mock_enable    <= r_control[1'd1];
            o_reset_fifo     <= r_control[1'd2];

            case (i_addr)
                ADDR_CTRL:   r_control <= i_write_data;
                ADDR_STATUS: r_status  <= i_write_data;
                default: ;
            endcase
        end
    end

    always_comb begin
        case (i_addr)
            ADDR_CTRL:   o_read_data = r_control;
            ADDR_STATUS: o_read_data = r_status;
            default:     o_read_data = 'hDEADBEEF;
        endcase
    end

endmodule
