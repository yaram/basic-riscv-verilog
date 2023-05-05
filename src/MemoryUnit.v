module MemoryUnit
#(
    parameter SIZE = 32,
    parameter STATION_INDEX_SIZE = 1,
    parameter BUS_COUNT = 1
) (
    input clock,
    input reset,

    input set_occupied,
    input reset_occupied,
    input operation,
    input [1 : 0]data_size,
    input is_signed,
    input preload_address_value,
    input [STATION_INDEX_SIZE - 1 : 0]address_source,
    input [SIZE - 1 : 0]preloaded_address_value,
    input [SIZE - 1 : 0]address_offset,
    input preload_data_value,
    input [STATION_INDEX_SIZE - 1 : 0]data_source,
    input [SIZE - 1 : 0]preloaded_data_value,

    output reg occupied,
    output result_ready,
    output reg [SIZE - 1 : 0]result,

    input `FLAT_ARRAY(bus_asserted, 1, BUS_COUNT),
    input `FLAT_ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT),
    input `FLAT_ARRAY(bus_value, SIZE, BUS_COUNT),

    output memory_enable,
    output memory_operation,
    input memory_ready,
    output [1 : 0]memory_data_size,
    output [SIZE - 1 : 0]memory_address,
    input [SIZE - 1 : 0]memory_data_in,
    output [SIZE - 1 : 0]memory_data_out
);
    genvar flatten_i;

    wire `ARRAY(bus_asserted, 1, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_asserted, 1, BUS_COUNT);
    wire `ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    wire `ARRAY(bus_value, SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_value, SIZE, BUS_COUNT);

    reg operation_performed;

    reg saved_operation;
    reg [1 : 0]saved_data_size;
    reg saved_is_signed;

    reg address_loaded;
    reg [SIZE - 1 : 0]address_value;
    reg [SIZE - 1 : 0]saved_address_offset;

    reg data_loaded;
    reg [SIZE - 1 : 0]data_value;

    reg [SIZE - 1 : 0]saved_memory_data_in;

    assign result_ready = occupied && operation_performed && !memory_ready;
    assign memory_enable = occupied && address_loaded && data_loaded && !operation_performed;
    assign memory_operation = saved_operation;
    assign memory_data_size = saved_data_size;
    assign memory_address = address_value + saved_address_offset;
    assign memory_data_out = data_value;

    integer i;

    reg address_value_found_on_bus;
    reg [SIZE - 1 : 0]address_value_on_bus;

    reg data_value_found_on_bus;
    reg [SIZE - 1 : 0]data_value_on_bus;

    always @* begin
        case (saved_data_size)
            0: begin
                if (saved_is_signed) begin
                    result = {{25{saved_memory_data_in[7]}}, saved_memory_data_in[6 : 0]};
                end else begin
                    result = {24'b0, saved_memory_data_in[7 : 0]};
                end
            end

            1: begin
                if (saved_is_signed) begin
                    result = {{17{saved_memory_data_in[15]}}, saved_memory_data_in[14 : 0]};
                end else begin
                    result = {16'b0, saved_memory_data_in[15 : 0]};
                end
            end

            2: begin
                result = saved_memory_data_in;
            end

            default: begin
                result = 0;
            end
        endcase

        address_value_found_on_bus = 0;
        address_value_on_bus = 0;
        data_value_found_on_bus = 0;
        data_value_on_bus = 0;
        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            if (!address_value_found_on_bus && bus_asserted[i] && bus_source[i] == address_source) begin
                address_value_found_on_bus = 1;
                data_value_on_bus = bus_value[i];
            end

            if (!data_value_found_on_bus && bus_asserted[i] && bus_source[i] == data_source) begin
                data_value_found_on_bus = 1;
                data_value_on_bus = bus_value[i];
            end
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            occupied <= 0;
        end else begin
            if (set_occupied) begin
                occupied <= 1;
                saved_operation <= operation;
                saved_data_size <= data_size;
                saved_is_signed <= is_signed;
                saved_address_offset <= address_offset;

                operation_performed <= 0;

                if (preload_address_value) begin
                    address_loaded <= 1;
                    address_value <= preloaded_address_value;
                end else begin
                    address_loaded <= 0;
                end

                if (preload_data_value) begin
                    data_loaded <= 1;
                    data_value <= preloaded_data_value;
                end else begin
                    data_loaded <= 0;
                end
            end else if(reset_occupied) begin
                occupied <= 0;
            end else if (occupied) begin
                if (!address_loaded && address_value_found_on_bus) begin
                    address_loaded <= 1;
                    address_value <= address_value_on_bus;
                end

                if (!data_loaded && data_value_found_on_bus) begin
                    data_loaded <= 1;
                    data_value <= data_value_on_bus;
                end

                if (memory_enable && memory_ready) begin
                    operation_performed <= 1;

                    saved_memory_data_in <= memory_data_in;
                end
            end
        end
    end
endmodule