module memory (
    input  logic        clock,
    input  logic [13:0] data,
    input  logic [12:0] rdaddress,
    input  logic [12:0] wraddress,
    input  logic        wren,
    output logic [13:0] q
);
    logic [13:0] mem[0:8191];
    logic [12:0] addr_reg;

    always_ff @(posedge clock) begin
        if (wren) mem[wraddress] <= data;
        addr_reg <= rdaddress;
        q        <= mem[addr_reg];
    end
endmodule
