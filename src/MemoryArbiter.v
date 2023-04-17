module MemoryArbiter
#(
    parameter SIZE = 32,
    parameter ACCESSOR_COUNT = 2
) (
    input wire clock,
    input wire reset,

    output reg memory_enable,
    output reg memory_operation,
    input memory_ready,
    output reg [1 : 0]memory_data_size,
    output reg [SIZE - 1 : 0]memory_address,
    input [SIZE - 1 : 0]memory_data_in,
    output reg [SIZE - 1 : 0]memory_data_out,

    input [ACCESSOR_COUNT - 1 : 0]accessor_memory_enable_flat,
    input [ACCESSOR_COUNT - 1 : 0]accessor_memory_operation_flat,
    output [ACCESSOR_COUNT - 1 : 0]accessor_memory_ready_flat,
    input [ACCESSOR_COUNT * 2 - 1 : 0]accessor_memory_data_size_flat,
    input [ACCESSOR_COUNT * SIZE - 1 : 0]accessor_memory_address_flat,
    output [ACCESSOR_COUNT * SIZE - 1 : 0]accessor_memory_data_in_flat,
    input [ACCESSOR_COUNT * SIZE - 1 : 0]accessor_memory_data_out_flat
);
    localparam ACCESSOR_INDEX_SIZE = $clog2(ACCESSOR_COUNT - 1);

    `UNFLATTEN(accessor_memory_enable, 1, ACCESSOR_COUNT);
    `UNFLATTEN(accessor_memory_operation, 1, ACCESSOR_COUNT);
    `UNFLATTEN_OUTPUT(accessor_memory_ready, 1, ACCESSOR_COUNT);
    `UNFLATTEN(accessor_memory_data_size, 2, ACCESSOR_COUNT);
    `UNFLATTEN(accessor_memory_address, SIZE, ACCESSOR_COUNT);
    `UNFLATTEN_OUTPUT(accessor_memory_data_in, SIZE, ACCESSOR_COUNT);
    `UNFLATTEN(accessor_memory_data_out, SIZE, ACCESSOR_COUNT);

    reg active;
    reg [ACCESSOR_INDEX_SIZE - 1 : 0]active_accessor_index;

    reg set_active;
    reg reset_active;
    reg [ACCESSOR_INDEX_SIZE - 1 : 0]next_active_accessor_index;

    integer i;

    always @* begin
        memory_operation = accessor_memory_operation[active_accessor_index];
        memory_data_size = accessor_memory_data_size[active_accessor_index];
        memory_address = accessor_memory_address[active_accessor_index];
        memory_data_out = accessor_memory_data_out[active_accessor_index];

        set_active = 0;
        reset_active = 0;
        next_active_accessor_index = 0;

        for (i = 0; i < ACCESSOR_COUNT; i = i + 1) begin
            accessor_memory_data_in[i] = memory_data_in;

            if (!active && !set_active && accessor_memory_enable[i]) begin
                set_active = 1;
                next_active_accessor_index = i;
            end

            accessor_memory_ready[i] = 0;

            if (active && active_accessor_index == i) begin
                accessor_memory_ready[i] = memory_ready;
                memory_enable = accessor_memory_enable[i];
            end
        end

        if (active && !memory_enable && !memory_ready) begin
            reset_active = 1;
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            active <= 0;
        end else begin
            if (set_active) begin
                active <= 1;
                active_accessor_index <= next_active_accessor_index;
            end else if(reset_active) begin
                active <= 0;
            end
        end
    end
endmodule