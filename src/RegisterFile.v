`include "flatten.v"

module RegisterFile
#(
    parameter SIZE = 32,
    parameter REGISTER_COUNT = 31,
    parameter READ_COUNT = 2,
    parameter WRITE_COUNT = 2
) (
    input clock,
    input reset,

    input [READ_COUNT * REGISTER_INDEX_SIZE - 1 : 0]read_index_flat,
    output [READ_COUNT * SIZE - 1 : 0]read_data_flat,

    input [WRITE_COUNT - 1 : 0]write_enable_flat,
    input [WRITE_COUNT * REGISTER_INDEX_SIZE - 1 : 0]write_index_flat,
    input [WRITE_COUNT * SIZE - 1 : 0]write_data_flat
);
    localparam REGISTER_INDEX_SIZE = $clog2(REGISTER_COUNT - 1);

    `UNFLATTEN(read_index, REGISTER_INDEX_SIZE, READ_COUNT);
    `UNFLATTEN_OUTPUT(read_data, SIZE, READ_COUNT);

    `UNFLATTEN(write_enable, 1, WRITE_COUNT);
    `UNFLATTEN(write_index, REGISTER_INDEX_SIZE, WRITE_COUNT);
    `UNFLATTEN(write_data, SIZE, WRITE_COUNT);

    reg [SIZE - 1 : 0]registers[0 : REGISTER_COUNT - 1];

    integer i;

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
        end
    end
endmodule