`default_nettype none

module StationParameter
#(
    parameter int SIZE = 32,
    parameter int STATION_INDEX_SIZE = 1,
    parameter int BUS_COUNT = 1
) (
    input clock,
    input reset,

    input occupied,

    input preload_value,
    input [SIZE - 1 : 0]preloaded_value,
    input [STATION_INDEX_SIZE - 1 : 0]source_index,

    output logic loaded,
    output logic [SIZE - 1 : 0]value,

    input bus_asserted[0 : BUS_COUNT - 1],
    input [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_COUNT - 1],
    input [SIZE - 1 : 0]bus_value[0 : BUS_COUNT - 1]
);
    logic previous_occupied;

    logic [STATION_INDEX_SIZE - 1 : 0]saved_source_index;

    logic value_found_on_bus;
    logic [SIZE - 1 : 0]value_on_bus;

    always_comb begin
        value_found_on_bus = 0;
        value_on_bus = 0;
        for (int i = 0; i < BUS_COUNT; i += 1) begin
            if (!value_found_on_bus && bus_asserted[i] && bus_source[i] == saved_source_index) begin
                value_found_on_bus = 1;
                value_on_bus = bus_value[i];
            end
        end
    end

    always_ff @(posedge clock) begin
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