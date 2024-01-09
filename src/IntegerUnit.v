module IntegerUnit
#(
    parameter SIZE = 32,
    parameter STATION_INDEX_SIZE = 1,
    parameter BUS_COUNT = 1
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
    output reg [SIZE - 1 : 0]result,

    input `FLAT_ARRAY(bus_asserted, 1, BUS_COUNT),
    input `FLAT_ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT),
    input `FLAT_ARRAY(bus_value, SIZE, BUS_COUNT)
);
    genvar flatten_i;

    wire `ARRAY(bus_asserted, 1, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_asserted, 1, BUS_COUNT);
    wire `ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    wire `ARRAY(bus_value, SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_value, SIZE, BUS_COUNT);

    reg previous_occupied;

    reg [3 : 0]saved_operation;

    wire a_loaded;
    wire [SIZE - 1 : 0]a_value;

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
        .bus_asserted_flat(bus_asserted_flat),
        .bus_source_flat(bus_source_flat),
        .bus_value_flat(bus_value_flat)
    );

    wire b_loaded;
    wire [SIZE - 1 : 0]b_value;

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
        .bus_asserted_flat(bus_asserted_flat),
        .bus_source_flat(bus_source_flat),
        .bus_value_flat(bus_value_flat)
    );

    assign result_ready = occupied && a_loaded && b_loaded;

    integer i;

    always @* begin
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

    always @(posedge clock) begin
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