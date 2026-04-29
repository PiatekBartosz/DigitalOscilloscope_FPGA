interface mcu_if #(parameter int DATA_WIDTH = 14);
    logic [DATA_WIDTH-1:0] data;
    logic                  write;
    logic                  ready;

    modport host  (input data, input write, output ready);
    modport device(output data, input write, input ready);
endinterface 
