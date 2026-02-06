#!/bin/bash

# Simple simulation script for Pipeline Register
# Auto-detects available simulator and runs tests

set -e  # Exit on error

echo "========================================="
echo "Pipeline Register - Quick Simulation"
echo "========================================="
echo ""

# Check for available simulators
if command -v iverilog &> /dev/null; then
    echo "✓ Found Icarus Verilog"
    SIM="icarus"
elif command -v vlog &> /dev/null; then
    echo "✓ Found ModelSim"
    SIM="modelsim"
elif command -v verilator &> /dev/null; then
    echo "✓ Found Verilator (lint only)"
    SIM="verilator"
else
    echo "✗ No simulator found!"
    echo "  Please install: Icarus Verilog, ModelSim, or Verilator"
    exit 1
fi

echo ""
echo "Running simulation with $SIM..."
echo ""

# Run simulation based on available tool
if [ "$SIM" = "icarus" ]; then
    # Icarus Verilog
    iverilog -g2012 -o sim_pipeline pipeline_register.sv pipeline_register_tb.sv
    vvp sim_pipeline
    echo ""
    echo "✓ Simulation complete!"
    echo "  View waveforms: gtkwave pipeline_register.vcd"
    
elif [ "$SIM" = "modelsim" ]; then
    # ModelSim
    vlib work 2>/dev/null || true
    vlog -sv pipeline_register.sv pipeline_register_tb.sv
    vsim -c -do "run -all; quit" pipeline_register_tb
    echo ""
    echo "✓ Simulation complete!"
    
elif [ "$SIM" = "verilator" ]; then
    # Verilator (lint only)
    verilator --lint-only -Wall --sv pipeline_register.sv
    echo ""
    echo "✓ Lint check passed!"
    echo "  (Full simulation requires C++ testbench)"
fi

echo ""
echo "========================================="
echo "Done!"
echo "========================================="
