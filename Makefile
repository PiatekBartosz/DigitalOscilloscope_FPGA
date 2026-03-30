PROJECT = digital_oscilloscope
TOP = digital_oscilloscope
QUARTUS_SH = quartus_sh
QUARTUS_PGM = quartus_pgm
QUARTUS_CPF = quartus_cpf

SRC = \
    src/digital_oscilloscope.sv \
    src/blinky/blinky.sv \
    src/fpga_control/fpga_control.sv

QIP = \
    src/clk/adc_clk.qip \
    src/spi_control/synthesis/spi_control.qip

SDC = digital_oscilloscope.sdc
PINS = pins.csv

.PHONY: all build program clean jic flash

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
	$(QUARTUS_PGM) -m jtag -o "p;$(PROJECT).jic"
	@echo "Flash Done!"

erase_flash:
	$(QUARTUS_PGM) -m jtag -o "e;$(PROJECT).jic"
	@echo "Flash Erase Done!"

clean:
	rm -rf db incremental_db output_files greybox_tmp simulation .qsys_edit
	rm -f *.rpt *.summary *.smsg *.done *.pin *.jdi *.sld *.map
	rm -f *.sof *.pof *.jic *.ekp
	rm -f *.qpf *.qsf *.qws
	rm -f *.sopcinfo
	rm -f qmegawiz_errors_log.txt
	rm -f src/*.bak src/**/*.bak src/**/**/*.bak
	@echo "Clean Done!"
