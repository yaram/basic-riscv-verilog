module Multiplier
#(
    parameter ITERATIONS_PER_CYCLE = 4, // Must be a factor of 2 * SIZE
    parameter SIZE = 32,
    parameter STATION_INDEX_SIZE = 1,
    parameter BUS_COUNT = 1
)
(
    input clock,
    input reset,

    input set_occupied,
    input reset_occupied,
    input [1 : 0]operation,
    input upper_result,
    input a_signed,
    input preload_a_value,
    input [STATION_INDEX_SIZE - 1 : 0]a_source,
    input [SIZE - 1 : 0]preloaded_a_value,
    input b_signed,
    input preload_b_value,
    input [STATION_INDEX_SIZE - 1 : 0]b_source,
    input [SIZE - 1 : 0]preloaded_b_value,

    output reg occupied,
    output reg result_ready,
    output reg [SIZE - 1 : 0]result,

    input `FLAT_ARRAY(bus_asserted, 1, BUS_COUNT),
    input `FLAT_ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT),
    input `FLAT_ARRAY(bus_value, SIZE, BUS_COUNT)
);
    genvar flatten_i;

    localparam ITERATION_INDEX_SIZE = $clog2(SIZE * 2);

    wire `ARRAY(bus_asserted, 1, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_asserted, 1, BUS_COUNT);
    wire `ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    wire `ARRAY(bus_value, SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_value, SIZE, BUS_COUNT);

    reg [1 : 0]saved_operation;
    reg saved_upper_result;
    reg saved_a_signed;
    reg saved_b_signed;

    reg a_loaded;
    reg [SIZE - 1 : 0]a_value;

    reg b_loaded;
    reg [SIZE - 1 : 0]b_value;

    integer i;

    reg a_value_found_on_bus;
    reg [SIZE - 1 : 0]a_value_on_bus;

    reg b_value_found_on_bus;
    reg [SIZE - 1 : 0]b_value_on_bus;

    reg [ITERATION_INDEX_SIZE - 1 : 0]iteration;
    reg [SIZE * 2 - 1 : 0]accumulator;
    reg [SIZE * 2 - 1 : 0]quotient;

    reg [SIZE * 2 - 1 : 0]extended_a_value;
    reg [SIZE * 2 - 1 : 0]extended_b_value;

    reg [ITERATION_INDEX_SIZE - 1 : 0]sub_cycle_iteration;
    reg [SIZE * 2 - 1 : 0]sub_cycle_accumulator;
    reg [SIZE * 2 - 1 : 0]sub_cycle_quotient;

    always @* begin
        result_ready = occupied && a_loaded && b_loaded && iteration == SIZE * 2;

        if (saved_a_signed) begin
            extended_a_value = {{SIZE{a_value[31]}}, a_value};
        end else begin
            extended_a_value = {{SIZE{1'b0}}, a_value};
        end

        if (saved_b_signed) begin
            extended_b_value = {{SIZE{b_value[31]}}, b_value};
        end else begin
            extended_b_value = {{SIZE{1'b0}}, b_value};
        end

        sub_cycle_iteration = iteration;
        sub_cycle_accumulator = accumulator;
        sub_cycle_quotient = quotient;

        for (i = 0; i < ITERATIONS_PER_CYCLE; i = i + 1) begin
            if (operation == 0) begin
                if (extended_b_value[SIZE * 2 - 1 - sub_cycle_iteration]) begin
                    sub_cycle_accumulator = sub_cycle_accumulator + extended_a_value;
                end
            end else begin
                if (extended_a_value[SIZE * 2 - 1] == 1) begin
                    extended_a_value = -extended_a_value;
                end

                if (extended_b_value[SIZE * 2 - 1] == 1) begin
                    extended_b_value = -extended_b_value;
                end

                sub_cycle_accumulator[0] = extended_a_value[SIZE * 2 - 1 - sub_cycle_iteration];

                if (sub_cycle_accumulator >= extended_b_value) begin
                    sub_cycle_accumulator = sub_cycle_accumulator - extended_b_value;

                    sub_cycle_quotient[SIZE * 2 - 1 - sub_cycle_iteration] = 1;
                end
            end

            sub_cycle_iteration = sub_cycle_iteration + 1;
        end

        case (saved_operation)
            0 : begin
                if (saved_upper_result) begin
                    result = accumulator[SIZE * 2 - 1 : SIZE];
                end else begin
                    result = accumulator[SIZE - 1 : 0];
                end
            end

            1 : begin
                if (extended_a_value[SIZE * 2 - 1] == extended_b_value[SIZE * 2 - 1]) begin
                    result = quotient[SIZE - 1 : 0];
                end else begin
                    result = -quotient[SIZE - 1 : 0];
                end
            end

            2 : begin
                if (!extended_a_value[SIZE * 2 - 1]) begin
                    result = accumulator[SIZE - 1 : 0];
                end else begin
                    result = -accumulator[SIZE - 1 : 0];
                end
            end

            default: begin
                result = 0;
            end
        endcase
    end

    always @(posedge clock) begin
        if (reset) begin
            occupied <= 0;
        end else begin
            if (set_occupied) begin
                occupied <= 1;
                saved_operation <= operation;
                saved_upper_result <= upper_result;
                saved_a_signed <= a_signed;
                saved_b_signed <= b_signed;

                iteration <= 0;
                accumulator <= 0;
                quotient <= 0;

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
            end else if(reset_occupied) begin
                occupied <= 0;
            end

            if (occupied) begin
                if (!a_loaded && a_value_found_on_bus) begin
                    a_loaded <= 1;
                    a_value <= a_value_on_bus;
                end

                if (!b_loaded && b_value_found_on_bus) begin
                    b_loaded <= 1;
                    b_value <= b_value_on_bus;
                end

                if (a_loaded && b_loaded && iteration != SIZE * 2) begin
                    iteration = sub_cycle_iteration;
                    accumulator = sub_cycle_accumulator;
                    quotient = sub_cycle_quotient;
                end
            end
        end
    end
endmodule