`default_nettype none

module Testbench(
    input reset,
    input clock
);
    parameter int ram_size = 1024 * 64;

    logic [7 : 0]ram[0 : ram_size - 1];

    initial begin
        $readmemh(`ROM_PATH, ram);
    end

    logic [31 : 0]memory_address;
    logic [31 : 0]memory_data_in;
    logic [31 : 0]memory_data_out;
    logic [1 : 0]memory_data_size;
    logic memory_enable;
    logic memory_operation;
    logic memory_ready;

    CPU cpu(clock, reset, memory_enable, memory_operation, memory_ready, memory_data_size, memory_address, memory_data_in, memory_data_out);

    always_ff @(posedge clock) begin
        if (reset) begin
            memory_ready <= 0;
        end else begin
            if (memory_enable) begin
                if (memory_operation == 0) begin
                    if (memory_address < ram_size) begin
                        if (memory_data_size == 0) begin
                            $display("RAM Memory Read: address %x, value %x", memory_address, ram[memory_address]);
                        end else if (memory_data_size == 1) begin
                            $display("RAM Memory Read: address %x, value %x", memory_address, {ram[memory_address + 1], ram[memory_address]});
                        end else begin
                            $display("RAM Memory Read: address %x, value %x", memory_address, {ram[memory_address + 3], ram[memory_address + 2], ram[memory_address + 1], ram[memory_address]});
                        end

                        memory_data_in[7 : 0] <= ram[memory_address];
                        if (memory_data_size >= 1) memory_data_in[15 : 8] <= ram[memory_address + 1];
                        if (memory_data_size >= 2) begin
                            memory_data_in[23 : 16] <= ram[memory_address + 2];
                            memory_data_in[31 : 24] <= ram[memory_address + 3];
                        end
                    end else begin
                        if (memory_data_size == 0) begin
                            $display("Out of Bounds Memory Read: address %x", memory_address);
                        end else if (memory_data_size == 1) begin
                            $display("Out of Bounds Memory Read: address %x", memory_address);
                        end else begin
                            $display("Out of Bounds Memory Read: address %x", memory_address);
                        end

                        $stop();
                    end

                    memory_ready <= 1;
                end else begin
                    if (memory_address < ram_size) begin
                        if (memory_data_size == 0) begin
                            $display("RAM Memory Write: address %x, old value %x, new value %x", memory_address, ram[memory_address], memory_data_out[7 : 0]);
                        end else if (memory_data_size == 1) begin
                            $display("RAM Memory Write: address %x, old value %x, new value %x", memory_address, {ram[memory_address + 1], ram[memory_address]}, memory_data_out[15 : 0]);
                        end else begin
                            $display("RAM Memory Write: address %x, old value %x, new value %x", memory_address, {ram[memory_address + 3], ram[memory_address + 2], ram[memory_address + 1], ram[memory_address]}, memory_data_out);
                        end

                        ram[memory_address] <= memory_data_out[7 : 0];
                        if (memory_data_size >= 1) ram[memory_address + 1] <= memory_data_out[15 : 8];
                        if (memory_data_size >= 2) begin
                            ram[memory_address + 2] <= memory_data_out[23 : 16];
                            ram[memory_address + 3] <= memory_data_out[31 : 24];
                        end
                    end else if (memory_address == 32'hFFFFFD) begin
                        $display("Test Passed: %d", memory_data_out[7 : 0]);

                        $finish();
                    end else if (memory_address == 32'hFFFFFE) begin
                        $display("Test Failed: %d", memory_data_out[7 : 0]);

                        $stop();
                    end else if (memory_address == 32'hFFFFFF) begin
                        $display("Debug Print: %d", memory_data_out[7 : 0]);
                    end else begin
                        if (memory_data_size == 0) begin
                            $display("Out of Bounds Memory Write: address %x, value %x", memory_address, memory_data_out[7 : 0]);
                        end else if (memory_data_size == 1) begin
                            $display("Out of Bounds Memory Write: address %x, value %x", memory_address, memory_data_out[15 : 0]);
                        end else begin
                            $display("Out of Bounds Memory Write: address %x, value %x", memory_address, memory_data_out);
                        end

                        $stop();
                    end

                    memory_ready <= 1;
                end
            end else begin
                if (memory_ready) begin
                    memory_ready <= 0;
                end
            end
        end
    end
endmodule