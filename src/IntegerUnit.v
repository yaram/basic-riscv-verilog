module IntegerUnit
#(
    parameter SIZE = 32,
    parameter STATION_INDEX_SIZE = 1,
    parameter BUS_COUNT = 1
) (
    input clock,
    input reset,

    input load,
    input set_unoccupied,
    input [3 : 0]operation,
    input preload_a_value,
    input [STATION_INDEX_SIZE - 1 : 0]a_source,
    input [SIZE - 1 : 0]preloaded_a_value,
    input preload_b_value,
    input [STATION_INDEX_SIZE - 1 : 0]b_source,
    input [SIZE - 1 : 0]preloaded_b_value,

    output reg occupied,
    output reg result_ready,
    output reg [SIZE - 1 : 0]result,

    input bus_asserted[0 : BUS_INDEX_SIZE - 1],
    input [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_INDEX_SIZE - 1],
    input [SIZE - 1 : 0]bus_value[0 : BUS_INDEX_SIZE - 1]
);
    localparam BUS_INDEX_SIZE = $clog2(BUS_COUNT - 1);

    reg a_loaded;
    reg [SIZE - 1 : 0]a_value;

    reg b_loaded;
    reg [SIZE - 1 : 0]b_value;

    integer i;

    reg a_value_found_on_bus;
    reg [SIZE - 1 : 0]a_value_on_bus;

    reg b_value_found_on_bus;
    reg [SIZE - 1 : 0]b_value_on_bus;

    always @* begin
        result_ready = a_loaded && b_loaded;

        case (operation)
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
                result = a_value < b_value;
            end

            9 : begin
                result = $signed(a_value) < $signed(b_value);
            end

            default : begin
                result = 0;
            end
        endcase

        a_value_found_on_bus = 0;
        b_value_found_on_bus = 0;
        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            if (!a_value_found_on_bus && !a_loaded && bus_asserted[i] && bus_source[i] == a_source) begin
                a_value_found_on_bus = 1;
                a_value_on_bus = bus_value[i];
            end

            if (!b_value_found_on_bus && !b_loaded && bus_asserted[i] && bus_source[i] == b_source) begin
                b_value_found_on_bus = 1;
                b_value_on_bus = bus_value[i];
            end
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            occupied <= 0;
        end else begin
            if (load) begin
                occupied <= 1;

                if (preload_a_value) begin
                    a_loaded <= 1;
                    a_value <= preloaded_a_value;
                end else begin
                    a_loaded <= 0;
                end

                if (preload_b_value) begin
                    b_loaded <= 1;
                    b_value <= preloaded_b_value;
                end else begin
                    b_loaded <= 0;
                end
            end else if (set_unoccupied) begin
                occupied <= 0;
            end else begin
                if (occupied) begin
                    if (!a_loaded && a_value_found_on_bus) begin
                        a_loaded <= 1;
                        a_value <= a_value_on_bus;
                    end

                    if (!b_loaded && b_value_found_on_bus) begin
                        b_loaded <= 1;
                        b_value <= a_value_on_bus;
                    end
                end
            end
        end
    end
endmodule