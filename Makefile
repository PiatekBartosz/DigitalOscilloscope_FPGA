PROJECT = digital_oscilloscope
QUARTUS_SH = quartus_sh
QUARTUS_PGM = quartus_pgm
QUARTUS_CPF = quartus_cpf

.PHONY: all clean build program jic flash

# Default target
all: build

# Full compile (analysis + synthesis + fit + asm)
build:
	$(QUARTUS_SH) --flow compile $(PROJECT)

# Program FPGA via JTAG (SOF)
program: build
# 	$(QUARTUS_PGM) -m jtag -o "p;output_files/$(PROJECT).sof"
	$(QUARTUS_PGM) -m jtag -o "p;$(PROJECT).sof"

# Generate JIC file
jic:
	$(QUARTUS_CPF) -c digital_oscilloscope.cof

# Program flash (JIC)
flash: jic
	$(QUARTUS_PGM) -m jtag -o "p;output_files/$(PROJECT).jic"

clean:
	rm -rf output_files db incremental_db