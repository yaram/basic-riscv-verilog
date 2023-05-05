module RegisterFile
#(
    parameter SIZE = 32,
    parameter REGISTER_COUNT = 31,
    parameter READ_COUNT = 2,
    parameter WRITE_COUNT = 2
) (
    input clock,
    input reset,

    input `FLAT_ARRAY(read_index, REGISTER_INDEX_SIZE, READ_COUNT),
    output `FLAT_ARRAY(read_data, SIZE, READ_COUNT),

    input `FLAT_ARRAY(write_enable, 1, WRITE_COUNT),
    input `FLAT_ARRAY(write_index, REGISTER_INDEX_SIZE, WRITE_COUNT),
    input `FLAT_ARRAY(write_data, SIZE, WRITE_COUNT)
);
    genvar flatten_i;

    localparam REGISTER_INDEX_SIZE = $clog2(REGISTER_COUNT);

    wire `ARRAY(read_index, REGISTER_INDEX_SIZE, READ_COUNT);
    `NORMAL_EQUALS_FLAT(read_index, REGISTER_INDEX_SIZE, READ_COUNT);
    reg `ARRAY(read_data, SIZE, READ_COUNT);
    `FLAT_EQUALS_NORMAL(read_data, SIZE, READ_COUNT);

    wire `ARRAY(write_enable, 1, WRITE_COUNT);
    `NORMAL_EQUALS_FLAT(write_enable, 1, WRITE_COUNT);
    wire `ARRAY(write_index, REGISTER_INDEX_SIZE, WRITE_COUNT);
    `NORMAL_EQUALS_FLAT(write_index, REGISTER_INDEX_SIZE, WRITE_COUNT);
    wire `ARRAY(write_data, SIZE, WRITE_COUNT);
    `NORMAL_EQUALS_FLAT(write_data, SIZE, WRITE_COUNT);

    reg [SIZE - 1 : 0]registers[0 : REGISTER_COUNT - 1];

    integer i;
    integer j;

    always @* begin
        for (i = 0; i < READ_COUNT; i = i + 1) begin
            read_data[i] = registers[read_index[i]];
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            for (i = 0; i < REGISTER_COUNT; i = i + 1) begin
                registers[i] <= 0;
            end
        end else begin
            for (i = 0; i < WRITE_COUNT; i = i + 1) begin
                if (write_enable[i]) begin
                    registers[write_index[i]] <= write_data[i];
                end
            end

            `ifdef SIMULATION
            // Sanity check for multiple writes to the same register
            for (i = 0; i < WRITE_COUNT; i = i + 1) begin
                for (j = 0; j < WRITE_COUNT; j = j + 1) begin
                    if (i != j && write_enable[i] && write_enable[j] && write_index[i] == write_index[j]) begin
                        $display("Simultaneous write to register %d from busses %d and %d", write_index[i], i, j);
                        $stop();
                    end
                end
            end
            `endif
        end
    end
endmodule