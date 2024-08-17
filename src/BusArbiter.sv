`default_nettype none

module BusArbiter
#(
    parameter int SIZE = 32,
    parameter int STATION_COUNT = 2,
    parameter int BUS_COUNT = 1
) (
    output logic bus_asserted[0 : BUS_COUNT - 1],
    output logic [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_COUNT - 1],
    output logic [SIZE - 1 : 0]bus_value[0 : BUS_COUNT - 1],

    input station_ready[0 : STATION_COUNT - 1],
    input [SIZE - 1 : 0]station_value[0 : STATION_COUNT - 1],
    output logic station_is_asserting[0 : STATION_COUNT - 1]
);
    localparam int STATION_INDEX_SIZE = $clog2(STATION_COUNT);

    always_comb begin
        for (int i = 0; i < BUS_COUNT; i += 1) begin
            bus_asserted[i] = 0;
            bus_source[i] = 0;
            bus_value[i] = 0;
        end

        for (int i = 0; i < STATION_COUNT; i += 1) begin
            station_is_asserting[i] = 0;

            for (int j = 0; j < BUS_COUNT; j += 1) begin
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