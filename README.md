# Basic RISC-V Verilog
**Warning: This is basically the first thing I've ever made in Verilog. Don't use this as a reference for good Verilog style. It's probably terrible.**

A basic out-of-order implementation of the RV32I ISA in Verilog with a [test suite](https://github.com/riscv/riscv-tests).

Requires Icarus Verilog and either llvm/clang 8 or lower with the experimental riscv32 target enabled OR llvm/clang 9 or higher to run the test suite.