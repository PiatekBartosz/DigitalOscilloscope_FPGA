PROJECT = digital_oscilloscope
QPF = quartus/$(PROJECT).qpf
QSF = quartus/$(PROJECT).qsf

QUARTUS_SH = quartus_sh
QUARTUS_PGM = quartus_pgm
QUARTUS_CPF = quartus_cpf

FPGA_DEVICE = EP4CE22
CONFIG_DEVICE = EPCS64

.PHONY: all clean build map fit asm sta program jic run

all: build

build:
	$(QUARTUS_SH) -t build.tcl

map:
	quartus_map $(PROJECT)

fit:
	quartus_fit $(PROJECT)

asm:
	quartus_asm $(PROJECT)

sta:
	quartus_sta $(PROJECT)

program:
	$(QUARTUS_PGM) -m jtag -o "p;output_files/$(PROJECT).sof"

# TODO: for now only works in gui
jic:
	$(QUARTUS_CPF) -c -f digital_oscilloscope.cof p;output_files/$(PROJECT).jic

flash: jic
	$(QUARTUS_PGM) -m jtag -o "p;output_files/$(PROJECT).jic"

clean:
	rm -rf output_files db incremental_db

run: build program

