`default_nettype none

module MemoryUnit
#(
    parameter int SIZE = 32,
    parameter int STATION_INDEX_SIZE = 1,
    parameter int BUS_COUNT = 1
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

    output logic occupied,
    output result_ready,
    output logic [SIZE - 1 : 0]result,

    input bus_asserted[0 : BUS_COUNT - 1],
    input [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_COUNT - 1],
    input [SIZE - 1 : 0]bus_value[0 : BUS_COUNT - 1],

    output memory_enable,
    output memory_operation,
    input memory_ready,
    output [1 : 0]memory_data_size,
    output [SIZE - 1 : 0]memory_address,
    input [SIZE - 1 : 0]memory_data_in,
    output [SIZE - 1 : 0]memory_data_out
);
    logic operation_performed;

    logic saved_operation;
    logic [1 : 0]saved_data_size;
    logic saved_is_signed;

    logic address_loaded;
    logic [SIZE - 1 : 0]address_value;
    logic [SIZE - 1 : 0]saved_address_offset;

    logic data_loaded;
    logic [SIZE - 1 : 0]data_value;

    logic [SIZE - 1 : 0]saved_memory_data_in;

    assign result_ready = occupied && operation_performed && !memory_ready;
    assign memory_enable = occupied && address_loaded && data_loaded && !operation_performed;
    assign memory_operation = saved_operation;
    assign memory_data_size = saved_data_size;
    assign memory_address = address_value + saved_address_offset;
    assign memory_data_out = data_value;

    logic address_value_found_on_bus;
    logic [SIZE - 1 : 0]address_value_on_bus;

    logic data_value_found_on_bus;
    logic [SIZE - 1 : 0]data_value_on_bus;

    always_comb begin
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
        for (int i = 0; i < BUS_COUNT; i += 1) begin
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

    always_ff @(posedge clock) begin
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