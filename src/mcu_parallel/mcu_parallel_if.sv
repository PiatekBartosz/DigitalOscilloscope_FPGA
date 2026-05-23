// Parallel bus interface – Bus_2_STM_Controller-inspired, 14-bit data bus.
//
// PE_dataBus (14-bit, bidirectional) is split here into unidirectional signals;
// digital_oscilloscope.sv reconstructs the tristate:
//
//   assign io_mcu_data     = data_oe ? data_out : 14'bz;
//   assign data_in         = io_mcu_data;
//
// addr[2:0]  = CFG_ADDR[2:0]         – register selector (3-bit, no L/H word needed)
// rw         = C7_Write_To_FPGA      – 1=MCU writes FPGA, 0=FPGA drives bus (MCU reads)
// req        = C3_Trigger_Clock_INP  – rising edge latches a write transaction
// inc        = Increment             – rising edge advances the sample-buffer read pointer
// req_echo   = C3_Trigger_Clock_OUT  – req echoed back to MCU during reads (rw=0)
// busy       = Status_FPGA_Busy      – asserted while FPGA not ready (MCU polls)

interface mcu_parallel_if;
    logic [2:0]  addr;     // CFG_ADDR[2:0]
    logic        rw;       // 1=MCU writes, 0=MCU reads
    logic        req;      // C3_Trigger_Clock_INP
    logic        inc;      // increment: advance sample pointer for bulk reads

    logic [13:0] data_in;   // captured from io_mcu_data when rw=1 (MCU drives bus)
    logic [13:0] data_out;  // driven onto io_mcu_data when rw=0 (FPGA drives bus)
    logic        data_oe;   // 1 = FPGA drives io_mcu_data

    logic        busy;      // Status_FPGA_Busy
    logic        req_echo;  // C3_Trigger_Clock_OUT

    modport host  (output addr, rw, req, inc, data_in,
                   input  data_out, data_oe, busy, req_echo);
    modport device(input  addr, rw, req, inc, data_in,
                   output data_out, data_oe, busy, req_echo);
endinterface
