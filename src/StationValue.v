module StationValue
#(
    parameter SIZE = 32,
    parameter STATION_INDEX_SIZE = 1,
    parameter BUS_COUNT = 1
) (
    input clock,
    input reset,

    input occupied,

    input preload_value,
    input [SIZE - 1 : 0]preloaded_value,
    input [STATION_INDEX_SIZE - 1 : 0]source_index,

    output reg loaded,
    output reg [SIZE - 1 : 0]value,

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

    integer i;

    reg previous_occupied;

    reg [STATION_INDEX_SIZE - 1 : 0]saved_source_index;

    reg value_found_on_bus;
    reg [SIZE - 1 : 0]value_on_bus;

    always @* begin
        value_found_on_bus = 0;
        value_on_bus = 0;
        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            if (!value_found_on_bus && bus_asserted[i] && bus_source[i] == saved_source_index) begin
                value_found_on_bus = 1;
                value_on_bus = bus_value[i];
            end
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            previous_occupied <= 0;
        end else begin
            previous_occupied <= occupied;

            if (occupied) begin
                if (!previous_occupied) begin
                    if (preload_value) begin
                        loaded <= 1;
                        value <= preloaded_value;
                    end else begin
                        loaded <= 0;
                        saved_source_index <= source_index;
                    end
                end else begin
                    if (!loaded && value_found_on_bus) begin
                        loaded <= 1;
                        value <= value_on_bus;
                    end
                end
            end
        end
    end
endmodule