interface mcu_parallel_if;
    // MCU → FPGA
    logic [ 7:0] ctrl;  // [2:0]=OP, [7:3]=PAYLOAD
    logic        rw;    // 0=write, 1=read
    logic        req;

    // FPGA → MCU
    logic [13:0] data;
    logic        ack;

    modport host  (output ctrl, output rw, output req, input  data, input  ack);
    modport device(input  ctrl, input  rw, input  req, output data, output ack);
endinterface
