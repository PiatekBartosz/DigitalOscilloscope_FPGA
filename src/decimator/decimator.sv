// Downsamples the ADC sample stream: outputs 1 sample for every i_factor
// input samples.  i_factor=0 and i_factor=1 both pass every sample through.
module decimator (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [10:0] i_factor,
    input  logic [13:0] i_ch1_data,
    input  logic [13:0] i_ch2_data,
    input  logic        i_valid,
    output logic [13:0] o_ch1_data,
    output logic [13:0] o_ch2_data,
    output logic        o_valid
);

    logic [10:0] r_count;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_count    <= 11'd0;
            o_ch1_data <= 14'd0;
            o_ch2_data <= 14'd0;
            o_valid    <= 1'b0;
        end else begin
            o_valid <= 1'b0;
            if (i_valid) begin
                if (r_count == 11'd0) begin
                    o_ch1_data <= i_ch1_data;
                    o_ch2_data <= i_ch2_data;
                    o_valid    <= 1'b1;
                    r_count    <= (i_factor > 11'd1) ? i_factor - 11'd1 : 11'd0;
                end else begin
                    r_count <= r_count - 11'd1;
                end
            end
        end
    end

endmodule
