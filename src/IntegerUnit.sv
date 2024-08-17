`default_nettype none

module IntegerUnit
#(
    parameter int SIZE = 32,
    parameter int STATION_INDEX_SIZE = 1,
    parameter int BUS_COUNT = 1
) (
    input clock,
    input reset,

    input occupied,
    input [3 : 0]operation,
    input preload_a_value,
    input [STATION_INDEX_SIZE - 1 : 0]a_source,
    input [SIZE - 1 : 0]preloaded_a_value,
    input preload_b_value,
    input [STATION_INDEX_SIZE - 1 : 0]b_source,
    input [SIZE - 1 : 0]preloaded_b_value,

    output result_ready,
    output logic [SIZE - 1 : 0]result,

    input bus_asserted[0 : BUS_COUNT - 1],
    input [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_COUNT - 1],
    input [SIZE - 1 : 0]bus_value[0 : BUS_COUNT - 1]
);
    logic previous_occupied;

    logic [3 : 0]saved_operation;

    logic a_loaded;
    logic [SIZE - 1 : 0]a_value;

    StationParameter #(
        .SIZE(SIZE),
        .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
        .BUS_COUNT(BUS_COUNT)
    ) a_parameter (
        .clock(clock),
        .reset(reset),
        .occupied(occupied),
        .preload_value(preload_a_value),
        .preloaded_value(preloaded_a_value),
        .source_index(a_source),
        .loaded(a_loaded),
        .value(a_value),
        .bus_asserted(bus_asserted),
        .bus_source(bus_source),
        .bus_value(bus_value)
    );

    logic b_loaded;
    logic [SIZE - 1 : 0]b_value;

    StationParameter #(
        .SIZE(SIZE),
        .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
        .BUS_COUNT(BUS_COUNT)
    ) b_parameter (
        .clock(clock),
        .reset(reset),
        .occupied(occupied),
        .preload_value(preload_b_value),
        .preloaded_value(preloaded_b_value),
        .source_index(b_source),
        .loaded(b_loaded),
        .value(b_value),
        .bus_asserted(bus_asserted),
        .bus_source(bus_source),
        .bus_value(bus_value)
    );

    assign result_ready = occupied && a_loaded && b_loaded;

    always_comb begin
        case (saved_operation)
            0 : begin
                result = a_value + b_value;
            end

            1 : begin
                result = a_value - b_value;
            end

            2 : begin
                result = a_value | b_value;
            end

            3 : begin
                result = a_value & b_value;
            end

            4 : begin
                result = a_value ^ b_value;
            end

            5 : begin
                result = a_value << b_value[4 : 0];
            end

            6 : begin
                result = a_value >> b_value[4 : 0];
            end

            7 : begin
                result = $signed(a_value) >>> b_value[4 : 0];
            end

            8 : begin
                result = 0;
                result[0] = a_value < b_value;
            end

            9 : begin
                result = 0;
                result[0] = $signed(a_value) < $signed(b_value);
            end

            default : begin
                result = 0;
            end
        endcase
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            previous_occupied <= 0;
        end else begin
            previous_occupied <= occupied;

            if (occupied) begin
                if (!previous_occupied) begin
                    saved_operation <= operation;
                end
            end
        end
    end
endmodule