`include "src/CPU.v"

module Testbench;
    parameter ram_size = 1024 * 64;

    reg clock = 0;

    reg [7 : 0]ram[0 : ram_size];

    integer i;

    initial begin
        for(i = 0; i < ram_size; i++) begin
            ram[i] = 0;
        end

        $readmemh("build/rom.hex", ram);

        cpu.registers[2] = ram_size - 1; // Set stack pointer to end of RAM
    end

    wire [31 : 0]memory_address;
    reg [31 : 0]memory_data_in = 0;
    wire [31 : 0]memory_data_out;
    wire [1 : 0]memory_data_size;
    wire memory_enable;
    wire memory_operation;
    reg memory_ready = 0;

    CPU cpu(clock, memory_address, memory_data_in, memory_data_out, memory_data_size, memory_enable, memory_operation, memory_ready);

    always @(posedge(memory_enable)) begin
        if (memory_enable == 1) begin
            if (memory_operation == 0) begin
                if (memory_data_size == 0) begin
                    $display("Memory Read: address %x, value %x", memory_address, ram[memory_address]);
                end else if (memory_data_size == 1) begin
                    $display("Memory Read: address %x, value %x", memory_address, {ram[memory_address + 1], ram[memory_address]});
                end else if (memory_data_size == 2) begin
                    $display("Memory Read: address %x, value %x", memory_address, {ram[memory_address + 3], ram[memory_address + 2], ram[memory_address + 1], ram[memory_address]});
                end

                memory_data_in[7 : 0] = ram[memory_address];
                if (memory_data_size >= 1) memory_data_in[15 : 8] = ram[memory_address + 1];
                if (memory_data_size >= 2) begin
                    memory_data_in[23 : 16] = ram[memory_address + 2];
                    memory_data_in[31 : 24] = ram[memory_address + 3];
                end

                memory_ready = 1;
                @(negedge memory_enable);
                memory_ready = 0;
            end else begin
                if (memory_data_size == 0) begin
                    $display("Memory Write: address %x, old value %x, new value %x", memory_address, ram[memory_address], memory_data_out[7 : 0]);
                end else if (memory_data_size == 1) begin
                    $display("Memory Write: address %x, old value %x, new value %x", memory_address, {ram[memory_address + 1], ram[memory_address]}, memory_data_out[15 : 0]);
                end else if (memory_data_size == 2) begin
                    $display("Memory Write: address %x, old value %x, new value %x", memory_address, {ram[memory_address + 3], ram[memory_address + 2], ram[memory_address + 1], ram[memory_address]}, memory_data_out);
                end

                ram[memory_address] = memory_data_out[7 : 0];
                if (memory_data_size >= 1) ram[memory_address + 1] = memory_data_out[15 : 8];
                if (memory_data_size >= 2) begin
                    ram[memory_address + 2] = memory_data_out[23 : 16];
                    ram[memory_address + 3] = memory_data_out[31 : 24];
                end

                memory_ready = 1;
                @(negedge memory_enable);
                memory_ready = 0;
            end
        end
    end

    initial begin
        forever begin
            $display("Program Counter: %0d", cpu.program_counter);
            #1 clock = 1;
            #1 clock = 0;
        end
    end
endmodule