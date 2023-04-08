`include "flatten.v"

module BusArbiter
#(
    parameter SIZE = 32,
    parameter STATION_COUNT = 1,
    parameter BUS_COUNT = 1
) (
    output [BUS_COUNT - 1: 0]bus_asserted_flat,
    output [BUS_COUNT * STATION_INDEX_SIZE - 1 : 0]bus_source_flat,
    output [BUS_COUNT * SIZE - 1 : 0]bus_value_flat,

    input [STATION_COUNT - 1 : 0]station_ready_flat,
    input [STATION_COUNT * SIZE - 1 : 0]station_value_flat,
    output [STATION_COUNT - 1 : 0]station_is_asserting_flat,
);
    localparam STATION_INDEX_SIZE = $clog2(STATION_COUNT - 1);
    localparam BUS_INDEX_SIZE = $clog2(BUS_COUNT - 1);

    `UNFLATTEN_OUTPUT(bus_asserted, 1, BUS_COUNT);
    `UNFLATTEN_OUTPUT(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `UNFLATTEN_OUTPUT(bus_value, SIZE, BUS_COUNT);

    `UNFLATTEN(station_ready, 1, STATION_COUNT);
    `UNFLATTEN(station_value, SIZE, STATION_COUNT);
    `UNFLATTEN_OUTPUT(station_is_asserting, 1, STATION_COUNT);

    integer i;
    integer j;

    always @* begin
        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            bus_asserted[i] = 0;
            bus_source[i] = 0;
        end

        for (i = 0; i < STATION_COUNT; i = i + 1) begin
            station_is_asserting[i] = 0;

            if (station_ready[i]) begin
                for (j = 0; j < BUS_COUNT; j = j + 1) begin
                    if (!bus_asserted[j] && !station_is_asserting[i]) begin
                        station_is_asserting[i] = 1;

                        bus_asserted[j] = 1;
                        bus_source[j] = i[STATION_INDEX_SIZE - 1 : 0];
                    end
                end
            end
        end
    end
endmodule