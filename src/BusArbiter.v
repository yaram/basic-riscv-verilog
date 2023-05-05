module BusArbiter
#(
    parameter SIZE = 32,
    parameter STATION_COUNT = 1,
    parameter BUS_COUNT = 1
) (
    output `FLAT_ARRAY(bus_asserted, 1, BUS_COUNT),
    output `FLAT_ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT),
    output `FLAT_ARRAY(bus_value, SIZE, BUS_COUNT),

    input `FLAT_ARRAY(station_ready, 1, STATION_COUNT),
    input `FLAT_ARRAY(station_value, SIZE, STATION_COUNT),
    output `FLAT_ARRAY(station_is_asserting, 1, STATION_COUNT)
);
    genvar flatten_i;

    localparam STATION_INDEX_SIZE = $clog2(STATION_COUNT);
    localparam BUS_INDEX_SIZE = $clog2(BUS_COUNT);

    reg `ARRAY(bus_asserted, 1, BUS_COUNT);
    `FLAT_EQUALS_NORMAL(bus_asserted, 1, BUS_COUNT);
    reg `ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `FLAT_EQUALS_NORMAL(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    reg `ARRAY(bus_value, SIZE, BUS_COUNT);
    `FLAT_EQUALS_NORMAL(bus_value, SIZE, BUS_COUNT);

    wire `ARRAY(station_ready, 1, STATION_COUNT);
    `NORMAL_EQUALS_FLAT(station_ready, 1, STATION_COUNT);
    wire `ARRAY(station_value, SIZE, STATION_COUNT);
    `NORMAL_EQUALS_FLAT(station_value, SIZE, STATION_COUNT);
    reg `ARRAY(station_is_asserting, 1, STATION_COUNT);
    `FLAT_EQUALS_NORMAL(station_is_asserting, 1, STATION_COUNT);

    integer i;
    integer j;

    always @* begin
        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            bus_asserted[i] = 0;
            bus_source[i] = 0;
            bus_value[i] = 0;
        end

        for (i = 0; i < STATION_COUNT; i = i + 1) begin
            station_is_asserting[i] = 0;

            for (j = 0; j < BUS_COUNT; j = j + 1) begin
                if (station_ready[i] && !station_is_asserting[i] && !bus_asserted[j]) begin
                    station_is_asserting[i] = 1;

                    bus_asserted[j] = 1;
                    bus_source[j] = i[STATION_INDEX_SIZE - 1 : 0];
                    bus_value[j] = station_value[i];
                end
            end
        end
    end
endmodule