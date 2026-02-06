# Makefile for Pipeline Register Simulation
# Supports multiple simulators: Icarus, ModelSim, Verilator

# Default simulator
SIM ?= icarus

# Source files
RTL = pipeline_register.sv
TB = pipeline_register_tb.sv

# Output files
VCD = pipeline_register.vcd
EXECUTABLE = sim_pipeline

# Colors for output
GREEN = \033[0;32m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: all clean sim waves help test

all: sim

# Icarus Verilog
icarus: $(RTL) $(TB)
	@echo "$(GREEN)Compiling with Icarus Verilog...$(NC)"
	iverilog -g2012 -o $(EXECUTABLE) $(RTL) $(TB)
	@echo "$(GREEN)Running simulation...$(NC)"
	vvp $(EXECUTABLE)
	@echo "$(GREEN)Done! View waveforms with: make waves$(NC)"

# ModelSim
modelsim: $(RTL) $(TB)
	@echo "$(GREEN)Compiling with ModelSim...$(NC)"
	vlib work
	vlog -sv $(RTL) $(TB)
	@echo "$(GREEN)Running simulation...$(NC)"
	vsim -c -do "run -all; quit" pipeline_register_tb
	@echo "$(GREEN)Done!$(NC)"

# Verilator (lint only)
verilator-lint: $(RTL)
	@echo "$(GREEN)Running Verilator lint check...$(NC)"
	verilator --lint-only -Wall --sv $(RTL)
	@echo "$(GREEN)Lint check passed!$(NC)"

# Verilator (full simulation requires C++ wrapper)
verilator: $(RTL)
	@echo "$(GREEN)Verilator simulation requires C++ testbench$(NC)"
	@echo "Use 'make verilator-lint' for lint checking"

# VCS
vcs: $(RTL) $(TB)
	@echo "$(GREEN)Compiling with VCS...$(NC)"
	vcs -sverilog +v2k -timescale=1ns/1ps $(RTL) $(TB)
	@echo "$(GREEN)Running simulation...$(NC)"
	./simv
	@echo "$(GREEN)Done!$(NC)"

# Default simulation based on SIM variable
sim:
ifeq ($(SIM),icarus)
	$(MAKE) icarus
else ifeq ($(SIM),modelsim)
	$(MAKE) modelsim
else ifeq ($(SIM),vcs)
	$(MAKE) vcs
else ifeq ($(SIM),verilator)
	$(MAKE) verilator-lint
else
	@echo "$(RED)Unknown simulator: $(SIM)$(NC)"
	@echo "Use: make SIM=<icarus|modelsim|vcs|verilator>"
endif

# View waveforms
waves:
	@if [ -f $(VCD) ]; then \
		echo "$(GREEN)Opening waveforms...$(NC)"; \
		gtkwave $(VCD) &; \
	else \
		echo "$(RED)No waveform file found. Run 'make sim' first.$(NC)"; \
	fi

# Quick test
test: sim
	@echo ""
	@echo "$(GREEN)======================================$(NC)"
	@echo "$(GREEN)Simulation completed successfully!$(NC)"
	@echo "$(GREEN)======================================$(NC)"

# Clean build files
clean:
	@echo "$(GREEN)Cleaning up...$(NC)"
	rm -rf $(EXECUTABLE) $(VCD)
	rm -rf work transcript vsim.wlf
	rm -rf csrc simv simv.daidir ucli.key
	rm -rf *.log *.vpd
	@echo "$(GREEN)Clean complete!$(NC)"

# Help
help:
	@echo "Pipeline Register Simulation Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make               - Run simulation with default simulator (Icarus)"
	@echo "  make sim           - Run simulation (specify with SIM=<simulator>)"
	@echo "  make icarus        - Simulate with Icarus Verilog"
	@echo "  make modelsim      - Simulate with ModelSim"
	@echo "  make vcs           - Simulate with VCS"
	@echo "  make verilator-lint - Lint check with Verilator"
	@echo "  make waves         - View waveforms with GTKWave"
	@echo "  make test          - Run simulation and report"
	@echo "  make clean         - Remove generated files"
	@echo "  make help          - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make SIM=icarus    - Use Icarus Verilog"
	@echo "  make SIM=modelsim  - Use ModelSim"
	@echo ""
