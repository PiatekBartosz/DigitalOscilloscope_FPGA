module adc_reader (
    input  logic        i_clk,
    input  logic [13:0] i_adc_pins,
    output logic        o_adc_oe_n,
    output logic [13:0] o_adc_data
);
    assign o_adc_oe_n = 1'b0;

    always_ff @(posedge i_clk) begin
        o_adc_data <= i_adc_pins;
    end
endmodule
