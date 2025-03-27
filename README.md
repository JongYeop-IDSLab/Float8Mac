# Float8Mac

A hardware implementation of a 16-way Float8 MAC (Multiply-Accumulate) unit optimized for neural network computations. This project implements a 3-stage pipelined architecture that processes Float8 (1-4-3 format) inputs and produces BFloat16 (1-8-7) outputs.

## Key Features

- 16-way parallel MAC operations
- Support for FP8 e4m3fn format
- 3-stage pipelined architecture
- Input format: Float8 (1-4-3)
- Output format: BFloat16 (1-8-7)
- Verification framework included

## Prerequisites

Before running the project, make sure to install the following dependencies:

```bash
# Install PyTorch (CPU version)
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install NumPy
pip3 install numpy
```

## How to Run

To run the simulation, use the following command:

```bash
make sim
```

This will:
1. Generate test vectors using Python scripts
2. Run the SystemVerilog testbench
3. Generate FSDB waveform files for debugging

## Project Structure

- `src/` - Contains the main SystemVerilog implementation
- `verification/` - Contains testbenches and Python test scripts
- `verification/hex/` - Contains input and reference data for testing