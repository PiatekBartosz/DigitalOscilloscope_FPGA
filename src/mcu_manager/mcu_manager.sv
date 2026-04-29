module mcu_manager #(
    parameter int DATA_WIDTH = 14
)(
    input  logic i_clk,
    input  logic i_rst_n,
    mcu_if.device mcu
);

    logic [DATA_WIDTH-1:0] data_o;
    logic [DATA_WIDTH-1:0] data_i;
    logic                  data_oe;

    assign mcu.data = data_oe ? data_o : 'z;
    assign data_i   = mcu.data;

    cfg_t cfg;

    typedef enum logic [1:0] {
        ADDR_SAMPLE_COUNT = 2'd0,
        ADDR_FREQUENCY    = 2'd1
    } addr_e;

    logic [1:0] addr;

    assign addr = data_i[1:0];

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            cfg      <= '0;
            mcu.ready <= 1'b0;
            data_oe  <= 1'b0;
        end
        else begin
            mcu.ready <= 1'b1;

            if (mcu.write) begin
                unique case (addr)
                    ADDR_SAMPLE_COUNT: cfg.sample_count <= data_i[7:0];
                    ADDR_FREQUENCY:    cfg.frequency_hz <= data_i[7:0];
                    default: ;
                endcase
            end
            else begin
                data_oe <= 1'b1;
                unique case (addr)
                    ADDR_SAMPLE_COUNT: data_o <= cfg.sample_count;
                    ADDR_FREQUENCY:    data_o <= cfg.frequency_hz;
                    default:           data_o <= '0;
                endcase
            end
        end
    end

endmodule
