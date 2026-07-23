interface mcu_parallel_if;
    logic [ 2:0] addr;
    logic        rw;
    logic        req;
    logic        inc;

    logic [13:0] data_in;
    logic [13:0] data_out;
    logic        data_oe;

    logic        busy;
    logic        req_echo;

    modport host(output addr, rw, req, inc, data_in, input data_out, data_oe, busy, req_echo);
    modport device(input addr, rw, req, inc, data_in, output data_out, data_oe, busy, req_echo);
endinterface
