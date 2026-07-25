### Options (sim only) ###
WAVE    ?= 0
VERBOSE ?= 0
###########################

PROJECT = digital_oscilloscope
TOP = digital_oscilloscope
QUARTUS_SH = quartus_sh
QUARTUS_PGM = quartus_pgm
QUARTUS_CPF = quartus_cpf
QUARTUS_DIR := $(shell dirname $(shell dirname $(shell readlink -f $(shell which $(QUARTUS_PGM)))))
SFL_SOF ?= $(QUARTUS_DIR)/common/devinfo/programmer/sfl_ep4ce22.sof
FLASH_JTAG_DEVICE ?= 1

SRC = \
    src/digital_oscilloscope.sv \
    src/blinky/blinky.sv \
    src/ltc2299/ltc2299.sv \
    src/mock_gen/mock_gen.sv \
    src/mcu_parallel/mcu_parallel_if.sv \
    src/mcu_parallel/mcu_parallel.sv \
    src/decimator/decimator.sv \
    src/trigger/trigger_ctrl.sv \
    src/memory/memory.v \
    src/memory/sample_buffer.sv

DEBUG_TOP = digital_oscilloscope_adc_debug
DEBUG_SRC = \
    src/digital_oscilloscope_adc_debug.sv \
    src/blinky/blinky.sv

FORMAT_TOOL = verible-verilog-format
FORMAT_ARGS = --flagfile=.verilog_format --inplace

QIP = \
    src/clk/adc_clk.qip

SDC = digital_oscilloscope.sdc
PINS = pins.csv

SIM_DIR = sim

TB1_TOP = tb_sample_buffer
TB1_RTL = src/memory/sample_buffer.sv
TB1_SRC = $(SIM_DIR)/memory_stub.sv $(SIM_DIR)/tb_sample_buffer.sv
TB1_VVP = $(SIM_DIR)/sim.vvp

TB2_TOP = tb_trigger_path
TB2_RTL = \
    src/trigger/trigger_ctrl.sv \
    src/mock_gen/mock_gen.sv \
    src/decimator/decimator.sv \
    src/memory/sample_buffer.sv
TB2_SRC = $(SIM_DIR)/memory_stub.sv $(SIM_DIR)/tb_trigger_path.sv
TB2_VVP = $(SIM_DIR)/sim_trigger.vvp

VVP_ARGS =
ifeq ($(VERBOSE),1)
  VVP_ARGS += +VERBOSE
endif
ifeq ($(WAVE),1)
  VVP_ARGS += +WAVE
endif

.PHONY: all build program clean jic flash build_debug program_debug sim sim_waves sim_clean

all: build program

build: $(PINS)
	$(QUARTUS_SH) -t build.tcl $(PROJECT) $(TOP) "$(SRC)" "$(QIP)" $(SDC)
	@echo "Build Done!"

program:
	$(QUARTUS_PGM) -m jtag -o "p;$(PROJECT).sof"
	@echo "Program Done!"

jic:
	$(QUARTUS_CPF) -c $(PROJECT).cof
	@echo "Jic Done!"

flash: jic
	@test -f "$(SFL_SOF)" || { echo "Serial Flash Loader not found: $(SFL_SOF)"; exit 2; }
	$(QUARTUS_PGM) -m jtag -o "p;$(SFL_SOF)@$(FLASH_JTAG_DEVICE)"
	$(QUARTUS_PGM) -m jtag -o "p;$(PROJECT).jic@$(FLASH_JTAG_DEVICE)"
	@echo "Flash Done!"

erase_flash:
	$(QUARTUS_PGM) -m jtag -o "e;$(PROJECT).jic"
	@echo "Flash Erase Done!"

build_debug: $(PINS)
	$(QUARTUS_SH) -t build.tcl $(DEBUG_TOP) $(DEBUG_TOP) "$(DEBUG_SRC)" "" $(SDC)
	@echo "Debug Build Done!"

program_debug:
	$(QUARTUS_PGM) -m jtag -o "p;$(DEBUG_TOP).sof"
	@echo "Debug Program Done!"

sim: $(TB1_VVP) $(TB2_VVP)
	cd $(SIM_DIR) && vvp $(notdir $(TB1_VVP)) $(VVP_ARGS)
	cd $(SIM_DIR) && vvp $(notdir $(TB2_VVP)) $(VVP_ARGS)
	@echo "Sim Done!"

$(TB1_VVP): $(TB1_RTL) $(TB1_SRC)
	iverilog -g2012 -s $(TB1_TOP) -o $(TB1_VVP) $(TB1_RTL) $(TB1_SRC)

$(TB2_VVP): $(TB2_RTL) $(TB2_SRC)
	iverilog -g2012 -s $(TB2_TOP) -o $(TB2_VVP) $(TB2_RTL) $(TB2_SRC)

sim_waves:
	@which surfer >/dev/null 2>&1 && surfer $(SIM_DIR)/waves.vcd $(SIM_DIR)/waves_trigger.vcd & || gtkwave $(SIM_DIR)/waves.vcd $(SIM_DIR)/waves_trigger.vcd &

sim_clean:
	rm -f $(TB1_VVP) $(TB2_VVP) $(SIM_DIR)/waves.vcd $(SIM_DIR)/waves_trigger.vcd
	@echo "Sim Clean Done!"

format:
	$(FORMAT_TOOL) $(FORMAT_ARGS) $(SRC)
	@echo "\nFormat Done!"

clean:
	rm -rf db incremental_db output_files greybox_tmp simulation .qsys_edit
	rm -f *.rpt *.summary *.smsg *.done *.pin *.jdi *.sld *.map
	rm -f *.sof *.pof *.jic *.ekp
	rm -f *.qpf *.qsf *.qws
	rm -f *.sopcinfo
	rm -f qmegawiz_errors_log.txt
	rm -f src/*.bak src/**/*.bak src/**/**/*.bak
	@echo "Clean Done!"
