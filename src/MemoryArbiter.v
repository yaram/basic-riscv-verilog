module MemoryArbiter
#(
    parameter SIZE = 32,
    parameter ACCESSOR_COUNT = 2
) (
    input wire clock,
    input wire reset,

    output reg memory_enable,
    output memory_operation,
    input memory_ready,
    output [SIZE_BYTES - 1 : 0]memory_byte_mask,
    output [MEMORY_WORD_ADDRESS_SIZE - 1 : 0]memory_word_address,
    input [SIZE - 1 : 0]memory_data_in,
    output [SIZE - 1 : 0]memory_data_out,

    input `FLAT_ARRAY(accessor_memory_enable, 1, ACCESSOR_COUNT),
    input `FLAT_ARRAY(accessor_memory_operation, 1, ACCESSOR_COUNT),
    output `FLAT_ARRAY(accessor_memory_ready, 1, ACCESSOR_COUNT),
    input `FLAT_ARRAY(accessor_memory_byte_mask, SIZE_BYTES, ACCESSOR_COUNT),
    input `FLAT_ARRAY(accessor_memory_word_address, MEMORY_WORD_ADDRESS_SIZE, ACCESSOR_COUNT),
    output `FLAT_ARRAY(accessor_memory_data_in, SIZE, ACCESSOR_COUNT),
    input `FLAT_ARRAY(accessor_memory_data_out, SIZE, ACCESSOR_COUNT)
);
    genvar flatten_i;

    localparam ACCESSOR_INDEX_SIZE = $clog2(ACCESSOR_COUNT);

    localparam SIZE_BYTES = SIZE / 8;
    localparam MEMORY_WORD_ADDRESS_SIZE = SIZE - $clog2(SIZE_BYTES);

    wire `ARRAY(accessor_memory_enable, 1, ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(accessor_memory_enable, 1, ACCESSOR_COUNT);
    wire `ARRAY(accessor_memory_operation, 1, ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(accessor_memory_operation, 1, ACCESSOR_COUNT);
    reg `ARRAY(accessor_memory_ready, 1, ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(accessor_memory_ready, 1, ACCESSOR_COUNT);
    wire `ARRAY(accessor_memory_byte_mask, SIZE_BYTES, ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(accessor_memory_byte_mask, SIZE_BYTES, ACCESSOR_COUNT);
    wire `ARRAY(accessor_memory_word_address, MEMORY_WORD_ADDRESS_SIZE, ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(accessor_memory_word_address, MEMORY_WORD_ADDRESS_SIZE, ACCESSOR_COUNT);
    reg `ARRAY(accessor_memory_data_in, SIZE, ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(accessor_memory_data_in, SIZE, ACCESSOR_COUNT);
    wire `ARRAY(accessor_memory_data_out, SIZE, ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(accessor_memory_data_out, SIZE, ACCESSOR_COUNT);

    reg active;
    reg [ACCESSOR_INDEX_SIZE - 1 : 0]active_accessor_index;

    reg set_active;
    reg reset_active;
    reg [ACCESSOR_INDEX_SIZE - 1 : 0]next_active_accessor_index;

    integer i;

    always @* begin
        memory_enable = 0;
        memory_operation = 0;
        memory_byte_mask = 0;
        memory_word_address = 0;
        memory_data_out = 0;

        set_active = 0;
        reset_active = 0;
        next_active_accessor_index = 0;

        for (i = 0; i < ACCESSOR_COUNT; i = i + 1) begin
            accessor_memory_data_in[i] = memory_data_in;

            accessor_memory_ready[i] = 0;
            if (i[ACCESSOR_INDEX_SIZE - 1 : 0] == active_accessor_index) begin
                if (active) begin
                    memory_enable = accessor_memory_enable[i];
                    accessor_memory_ready[i] = memory_ready;
                end

                memory_operation = accessor_memory_operation[i];
                memory_byte_mask = accessor_memory_byte_mask[i];
                memory_word_address = accessor_memory_word_address[i];
                memory_data_out = accessor_memory_data_out[i];
            end
        end

        if (active) begin
            if (!memory_enable && !memory_ready) begin
                reset_active = 1;
            end
        end else begin
            for (i = 0; i < ACCESSOR_COUNT; i = i + 1) begin
                if (!set_active && accessor_memory_enable[i]) begin
                    set_active = 1;
                    next_active_accessor_index = i[ACCESSOR_INDEX_SIZE - 1 : 0];
                end
            end
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