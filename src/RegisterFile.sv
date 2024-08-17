`default_nettype none

// Multiple write to the same register on the same clock cycle will cause the write on the the higher-index write port to be discarded!
module RegisterFile
#(
    parameter int SIZE = 32,
    parameter int REGISTER_COUNT = 31,
    parameter int READ_COUNT = 2,
    parameter int WRITE_COUNT = 2
) (
    input clock,
    input reset,

    input [REGISTER_INDEX_SIZE - 1 : 0]read_index[0 : READ_COUNT - 1],
    output logic [SIZE - 1 : 0]read_data[0 : READ_COUNT - 1],

    input write_enable[0 : WRITE_COUNT - 1],
    input [REGISTER_INDEX_SIZE - 1 : 0]write_index[0 : WRITE_COUNT - 1],
    input [SIZE - 1 : 0]write_data[0 : WRITE_COUNT - 1]
);
    localparam int REGISTER_INDEX_SIZE = $clog2(REGISTER_COUNT);

    logic [SIZE - 1 : 0]registers[0 : REGISTER_COUNT - 1];

    logic register_being_written[0 : REGISTER_COUNT - 1];
    logic [SIZE - 1 : 0]register_write_value[0 : REGISTER_COUNT - 1];

    always_comb begin
            for (int i = 0; i < READ_COUNT; i += 1) begin
                read_data[i] = 0;

                for (int j = 0; j < REGISTER_COUNT; j += 1) begin
                    if (read_index[i] == j[REGISTER_INDEX_SIZE - 1 : 0]) begin
                        read_data[i] = registers[j];
                    end
                end
            end

        for (int i = 0; i < REGISTER_COUNT; i += 1) begin
            register_being_written[i] = 0;
            register_write_value[i] = 0;

            for (int j = 0; j < WRITE_COUNT; j += 1) begin
                if (!register_being_written[i] && write_enable[j] && write_index[j] == i[REGISTER_INDEX_SIZE - 1 : 0]) begin
                    register_being_written[i] = 1;
                    register_write_value[i] = write_data[j];
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < REGISTER_COUNT; i += 1) begin
                registers[i] <= 0;
            end
        end else begin
            for (int i = 0; i < REGISTER_COUNT; i += 1) begin
                if (register_being_written[i]) begin
                    registers[i] <= register_write_value[i];
                end
            end

            `ifdef SIMULATION
            // Sanity check for multiple writes to the same register
            for (int i = 0; i < WRITE_COUNT; i += 1) begin
                for (int j = 0; j < WRITE_COUNT; j += 1) begin
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