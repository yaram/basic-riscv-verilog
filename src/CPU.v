module CPU (
    input clock,
    input reset,

    output memory_enable,
    output memory_operation,
    input memory_ready,
    output [1 : 0]memory_data_size,
    output [SIZE - 1 : 0]memory_address,
    input [SIZE - 1 : 0]memory_data_in,
    output [SIZE - 1 : 0]memory_data_out
);
    genvar flatten_i;
    genvar genvar_i;

    localparam SIZE = 32;

    localparam INTEGER_UNIT_COUNT = 4;
    localparam FIRST_INTEGER_UNIT_STATION = 0;
    localparam INTEGER_UNIT_INDEX_SIZE = $clog2(INTEGER_UNIT_COUNT);

    localparam MULTIPLIER_COUNT = 2;
    localparam FIRST_MULTIPLIER_STATION = INTEGER_UNIT_COUNT;
    localparam MULTIPLIER_INDEX_SIZE = $clog2(MULTIPLIER_COUNT);

    localparam MEMORY_UNIT_STATION = FIRST_MULTIPLIER_STATION + MULTIPLIER_COUNT;

    localparam STATION_COUNT = MEMORY_UNIT_STATION + 1;
    localparam STATION_INDEX_SIZE = $clog2(STATION_COUNT);

    localparam BUS_COUNT = 2;
    localparam BUS_INDEX_SIZE = $clog2(BUS_COUNT);

    localparam REGISTER_COUNT = 31;
    localparam REGISTER_INDEX_SIZE = $clog2(REGISTER_COUNT);

    localparam REGISTER_READ_COUNT = 2;
    localparam REGISTER_WRITE_COUNT = BUS_COUNT + 1;

    localparam MEMORY_ACCESSOR_COUNT = 2;

    reg halted;

    reg should_halt;

    reg instruction_load_loaded;
    reg instruction_load_canceling;
    reg [SIZE - 1 : 0]instruction_load_program_counter;
    reg instruction_load_memory_enable;
    reg instruction_load_memory_operation;
    wire instruction_load_memory_ready;
    reg [1 : 0]instruction_load_memory_data_size;
    reg [SIZE - 1 : 0]instruction_load_memory_address;
    wire [SIZE - 1 : 0]instruction_load_memory_data_in;

    assign memory_arbiter_accessor_memory_enable[1] = instruction_load_memory_enable;
    assign memory_arbiter_accessor_memory_operation[1] = instruction_load_memory_operation;
    assign instruction_load_memory_ready = memory_arbiter_accessor_memory_ready[1];
    assign memory_arbiter_accessor_memory_data_size[1] = instruction_load_memory_data_size;
    assign memory_arbiter_accessor_memory_address[1] = instruction_load_memory_address;
    assign instruction_load_memory_data_in = memory_arbiter_accessor_memory_data_in[1];
    assign memory_arbiter_accessor_memory_data_out[1] = 0;

    reg [31 : 0]instruction;
    reg [SIZE - 1 : 0]instruction_program_counter;

    wire decoder_valid_instruction;
    wire [4 : 0]decoder_source_1_register_index;
    wire decoder_source_2_is_immediate;
    wire [4 : 0]decoder_source_2_register_index;
    wire [31 : 0]decoder_source_2_immediate_value;
    wire [4 : 0]decoder_destination_register_index;
    wire decoder_integer_unit;
    wire [3 : 0]decoder_integer_unit_operation;
    wire decoder_multiplier;
    wire [1 : 0]decoder_multiplier_operation;
    wire decoder_multiplier_source_1_signed;
    wire decoder_multiplier_source_2_signed;
    wire decoder_multiplier_upper_result;
    wire decoder_load_immediate;
    wire decoder_load_immediate_add_instruction_counter;
    wire [31 : 0]decoder_load_immediate_value;
    wire decoder_branch;
    wire [2 : 0]decoder_branch_condition;
    wire [31 : 0]decoder_branch_immediate;
    wire decoder_jump_and_link;
    wire decoder_jump_and_link_relative;
    wire [31 : 0]decoder_jump_and_link_immediate;
    wire [31 : 0]decoder_jump_and_link_relative_immediate;
    wire decoder_memory_unit;
    wire decoder_memory_unit_operation;
    wire [1 : 0]decoder_memory_unit_data_size;
    wire decoder_memory_unit_signed;
    wire [31 : 0]decoder_memory_unit_address_offset_immediate;
    wire decoder_fence;

    InstructionDecoder instruction_decoder (
        .instruction(instruction),
        .valid_instruction(decoder_valid_instruction),
        .source_1_register_index(decoder_source_1_register_index),
        .source_2_is_immediate(decoder_source_2_is_immediate),
        .source_2_register_index(decoder_source_2_register_index),
        .source_2_immediate_value(decoder_source_2_immediate_value),
        .destination_register_index(decoder_destination_register_index),
        .integer_unit(decoder_integer_unit),
        .integer_unit_operation(decoder_integer_unit_operation),
        .multiplier(decoder_multiplier),
        .multiplier_operation(decoder_multiplier_operation),
        .multiplier_source_1_signed(decoder_multiplier_source_1_signed),
        .multiplier_source_2_signed(decoder_multiplier_source_2_signed),
        .multiplier_upper_result(decoder_multiplier_upper_result),
        .load_immediate(decoder_load_immediate),
        .load_immediate_add_instruction_counter(decoder_load_immediate_add_instruction_counter),
        .load_immediate_value(decoder_load_immediate_value),
        .branch(decoder_branch),
        .branch_condition(decoder_branch_condition),
        .branch_immediate(decoder_branch_immediate),
        .jump_and_link(decoder_jump_and_link),
        .jump_and_link_relative(decoder_jump_and_link_relative),
        .jump_and_link_immediate(decoder_jump_and_link_immediate),
        .jump_and_link_relative_immediate(decoder_jump_and_link_relative_immediate),
        .memory_unit(decoder_memory_unit),
        .memory_unit_operation(decoder_memory_unit_operation),
        .memory_unit_data_size(decoder_memory_unit_data_size),
        .memory_unit_signed(decoder_memory_unit_signed),
        .memory_unit_address_offset_immediate(decoder_memory_unit_address_offset_immediate),
        .fence(decoder_fence)
    );

    reg load_next_instruction;
    reg cancel_loading_instruction;
    reg [SIZE - 1 : 0]next_instruction_load_program_counter;
    reg set_register_waiting[0 : 30];
    reg [STATION_INDEX_SIZE - 1 : 0]next_register_station_index[0 : 30];
    reg reset_register_waiting[0 : 30];

    reg unoccupied_integer_unit_found;
    reg [INTEGER_UNIT_INDEX_SIZE - 1 : 0]unoccupied_integer_unit_index;
    wire [STATION_INDEX_SIZE - 1 : 0]unoccupied_integer_unit_station = FIRST_INTEGER_UNIT_STATION + {{(STATION_INDEX_SIZE -  INTEGER_UNIT_INDEX_SIZE){1'b0}}, unoccupied_integer_unit_index};
    reg unoccupied_multiplier_found;
    reg [MULTIPLIER_INDEX_SIZE - 1 : 0]unoccupied_multiplier_index;
    wire [STATION_INDEX_SIZE - 1 : 0]unoccupied_multiplier_station = FIRST_MULTIPLIER_STATION + {{(STATION_INDEX_SIZE -  MULTIPLIER_INDEX_SIZE){1'b0}}, unoccupied_multiplier_index};
    reg source_1_on_bus;
    reg [SIZE - 1 : 0]source_1_bus_value;
    reg source_2_on_bus;
    reg [SIZE - 1 : 0]source_2_bus_value;
    wire [SIZE - 1 : 0]branch_destination = instruction_program_counter + decoder_branch_immediate;
    reg branch_result;
    reg [SIZE - 1 : 0]jump_and_link_destination;

    wire `ARRAY(bus_asserted, 1, BUS_COUNT);
    wire `FLAT_ARRAY(bus_asserted, 1, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_asserted, 1, BUS_COUNT);
    wire `ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    wire `FLAT_ARRAY(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_source, STATION_INDEX_SIZE, BUS_COUNT);
    wire `ARRAY(bus_value, SIZE, BUS_COUNT);
    wire `FLAT_ARRAY(bus_value, SIZE, BUS_COUNT);
    `NORMAL_EQUALS_FLAT(bus_value, SIZE, BUS_COUNT);

    reg register_waiting[0 : 30];
    reg [STATION_INDEX_SIZE - 1 : 0]register_station_index[0 : 30];

    reg `ARRAY(register_read_index, REGISTER_INDEX_SIZE, REGISTER_READ_COUNT);
    wire `FLAT_ARRAY(register_read_index, REGISTER_INDEX_SIZE, REGISTER_READ_COUNT);
    `FLAT_EQUALS_NORMAL(register_read_index, REGISTER_INDEX_SIZE, REGISTER_READ_COUNT);
    wire `ARRAY(register_read_data, SIZE, REGISTER_READ_COUNT);
    wire `FLAT_ARRAY(register_read_data, SIZE, REGISTER_READ_COUNT);
    `NORMAL_EQUALS_FLAT(register_read_data, SIZE, REGISTER_READ_COUNT);
    reg `ARRAY(register_write_enable, 1, REGISTER_WRITE_COUNT);
    wire `FLAT_ARRAY(register_write_enable, 1, REGISTER_WRITE_COUNT);
    `FLAT_EQUALS_NORMAL(register_write_enable, 1, REGISTER_WRITE_COUNT);
    reg `ARRAY(register_write_index, REGISTER_INDEX_SIZE, REGISTER_WRITE_COUNT);
    wire `FLAT_ARRAY(register_write_index, REGISTER_INDEX_SIZE, REGISTER_WRITE_COUNT);
    `FLAT_EQUALS_NORMAL(register_write_index, REGISTER_INDEX_SIZE, REGISTER_WRITE_COUNT);
    reg `ARRAY(register_write_data, SIZE, REGISTER_WRITE_COUNT);
    wire `FLAT_ARRAY(register_write_data, SIZE, REGISTER_WRITE_COUNT);
    `FLAT_EQUALS_NORMAL(register_write_data, SIZE, REGISTER_WRITE_COUNT);

    RegisterFile #(
        .SIZE(SIZE),
        .REGISTER_COUNT(31),
        .READ_COUNT(REGISTER_READ_COUNT),
        .WRITE_COUNT(REGISTER_WRITE_COUNT)
    ) register_file (
        .clock(clock),
        .reset(reset),
        .read_index_flat(register_read_index_flat),
        .read_data_flat(register_read_data_flat),
        .write_enable_flat(register_write_enable_flat),
        .write_index_flat(register_write_index_flat),
        .write_data_flat(register_write_data_flat)
    );

    reg source_1_present;
    wire [STATION_INDEX_SIZE - 1 : 0]source_1_source = register_station_index[decoder_source_1_register_index - 1];
    wire source_1_waiting = register_waiting[decoder_source_1_register_index - 1];
    reg [SIZE - 1 : 0]source_1_value;
    reg source_2_present;
    wire [STATION_INDEX_SIZE - 1 : 0]source_2_source = register_station_index[decoder_source_2_register_index - 1];
    wire source_2_waiting = register_waiting[decoder_source_2_register_index - 1];
    reg [SIZE - 1 : 0]source_2_value;
    wire destination_waiting = register_waiting[decoder_destination_register_index - 1];

    wire `ARRAY(station_ready, 1, STATION_COUNT);
    wire `FLAT_ARRAY(station_ready, 1, STATION_COUNT);
    `FLAT_EQUALS_NORMAL(station_ready, 1, STATION_COUNT);
    wire `ARRAY(station_value, SIZE, STATION_COUNT);
    wire `FLAT_ARRAY(station_value, SIZE, STATION_COUNT);
    `FLAT_EQUALS_NORMAL(station_value, SIZE, STATION_COUNT);
    wire `ARRAY(station_is_asserting, 1, STATION_COUNT);
    wire `FLAT_ARRAY(station_is_asserting, 1, STATION_COUNT);
    `NORMAL_EQUALS_FLAT(station_is_asserting, 1, STATION_COUNT);

    reg integer_unit_set_occupied[0 : INTEGER_UNIT_COUNT - 1];
    wire integer_unit_occupied[0 : INTEGER_UNIT_COUNT - 1];

    generate
        for (genvar_i = 0; genvar_i < INTEGER_UNIT_COUNT; genvar_i = genvar_i + 1) begin
            IntegerUnit #(
                .SIZE(SIZE),
                .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
                .BUS_COUNT(BUS_COUNT)
            ) integer_unit (
                .clock(clock),
                .reset(reset),
                .set_occupied(integer_unit_set_occupied[genvar_i]),
                .reset_occupied(station_is_asserting[FIRST_INTEGER_UNIT_STATION + genvar_i]),
                .operation(decoder_integer_unit_operation),
                .preload_a_value(source_1_present),
                .a_source(source_1_source),
                .preloaded_a_value(source_1_value),
                .preload_b_value(source_2_present),
                .b_source(source_2_source),
                .preloaded_b_value(source_2_value),
                .occupied(integer_unit_occupied[genvar_i]),
                .result_ready(station_ready[FIRST_INTEGER_UNIT_STATION + genvar_i]),
                .result(station_value[FIRST_INTEGER_UNIT_STATION + genvar_i]),
                .bus_asserted_flat(bus_asserted_flat),
                .bus_source_flat(bus_source_flat),
                .bus_value_flat(bus_value_flat)
            );
        end
    endgenerate

    reg multiplier_set_occupied[0 : MULTIPLIER_COUNT - 1];
    wire multiplier_occupied[0 : MULTIPLIER_COUNT - 1];

    generate
        for (genvar_i = 0; genvar_i < MULTIPLIER_COUNT; genvar_i = genvar_i + 1) begin
            Multiplier #(
                .SIZE(SIZE),
                .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
                .BUS_COUNT(BUS_COUNT)
            ) multiplier (
                .clock(clock),
                .reset(reset),
                .set_occupied(multiplier_set_occupied[genvar_i]),
                .reset_occupied(station_is_asserting[FIRST_MULTIPLIER_STATION + genvar_i]),
                .operation(decoder_multiplier_operation),
                .upper_result(decoder_multiplier_upper_result),
                .a_signed(decoder_multiplier_source_1_signed),
                .preload_a_value(source_1_present),
                .a_source(source_1_source),
                .preloaded_a_value(source_1_value),
                .b_signed(decoder_multiplier_source_2_signed),
                .preload_b_value(source_2_present),
                .b_source(source_2_source),
                .preloaded_b_value(source_2_value),
                .occupied(multiplier_occupied[genvar_i]),
                .result_ready(station_ready[FIRST_MULTIPLIER_STATION + genvar_i]),
                .result(station_value[FIRST_MULTIPLIER_STATION + genvar_i]),
                .bus_asserted_flat(bus_asserted_flat),
                .bus_source_flat(bus_source_flat),
                .bus_value_flat(bus_value_flat)
            );
        end
    endgenerate

    reg memory_unit_set_occupied;
    wire memory_unit_occupied;

    MemoryUnit #(
        .SIZE(SIZE),
        .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
        .BUS_COUNT(BUS_COUNT)
    ) memory_unit (
        .clock(clock),
        .reset(reset),
        .set_occupied(memory_unit_set_occupied),
        .reset_occupied(station_is_asserting[MEMORY_UNIT_STATION]),
        .operation(decoder_memory_unit_operation),
        .data_size(decoder_memory_unit_data_size),
        .is_signed(decoder_memory_unit_signed),
        .preload_address_value(source_1_present),
        .address_source(source_1_source),
        .preloaded_address_value(source_1_value),
        .address_offset(decoder_memory_unit_address_offset_immediate),
        .preload_data_value(source_2_present),
        .data_source(source_2_source),
        .preloaded_data_value(source_2_value),
        .occupied(memory_unit_occupied),
        .result_ready(station_ready[MEMORY_UNIT_STATION]),
        .result(station_value[MEMORY_UNIT_STATION]),
        .bus_asserted_flat(bus_asserted_flat),
        .bus_source_flat(bus_source_flat),
        .bus_value_flat(bus_value_flat),
        .memory_enable(memory_arbiter_accessor_memory_enable[0]),
        .memory_operation(memory_arbiter_accessor_memory_operation[0]),
        .memory_ready(memory_arbiter_accessor_memory_ready[0]),
        .memory_data_size(memory_arbiter_accessor_memory_data_size[0]),
        .memory_address(memory_arbiter_accessor_memory_address[0]),
        .memory_data_in(memory_arbiter_accessor_memory_data_in[0]),
        .memory_data_out(memory_arbiter_accessor_memory_data_out[0])
    );

    BusArbiter #(
        .SIZE(SIZE),
        .STATION_COUNT(STATION_COUNT),
        .BUS_COUNT(BUS_COUNT)
    ) bus_arbiter (
        .bus_asserted_flat(bus_asserted_flat),
        .bus_source_flat(bus_source_flat),
        .bus_value_flat(bus_value_flat),
        .station_ready_flat(station_ready_flat),
        .station_value_flat(station_value_flat),
        .station_is_asserting_flat(station_is_asserting_flat)
    );

    wire `ARRAY(memory_arbiter_accessor_memory_enable, 1, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_enable, 1, MEMORY_ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(memory_arbiter_accessor_memory_enable, 1, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_operation, 1, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_operation, 1, MEMORY_ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(memory_arbiter_accessor_memory_operation, 1, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_ready, 1, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_ready, 1, MEMORY_ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(memory_arbiter_accessor_memory_ready, 1, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_data_size, 2, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_data_size, 2, MEMORY_ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(memory_arbiter_accessor_memory_data_size, 2, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_address, SIZE, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_address, SIZE, MEMORY_ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(memory_arbiter_accessor_memory_address, SIZE, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_data_in, SIZE, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_data_in, SIZE, MEMORY_ACCESSOR_COUNT);
    `NORMAL_EQUALS_FLAT(memory_arbiter_accessor_memory_data_in, SIZE, MEMORY_ACCESSOR_COUNT);
    wire `ARRAY(memory_arbiter_accessor_memory_data_out, SIZE, MEMORY_ACCESSOR_COUNT);
    wire `FLAT_ARRAY(memory_arbiter_accessor_memory_data_out, SIZE, MEMORY_ACCESSOR_COUNT);
    `FLAT_EQUALS_NORMAL(memory_arbiter_accessor_memory_data_out, SIZE, MEMORY_ACCESSOR_COUNT);

    MemoryArbiter #(
        .SIZE(SIZE),
        .ACCESSOR_COUNT(MEMORY_ACCESSOR_COUNT)
    ) memory_arbiter (
        .clock(clock),
        .reset(reset),
        .memory_enable(memory_enable),
        .memory_operation(memory_operation),
        .memory_ready(memory_ready),
        .memory_data_size(memory_data_size),
        .memory_address(memory_address),
        .memory_data_in(memory_data_in),
        .memory_data_out(memory_data_out),
        .accessor_memory_enable_flat(memory_arbiter_accessor_memory_enable_flat),
        .accessor_memory_operation_flat(memory_arbiter_accessor_memory_operation_flat),
        .accessor_memory_ready_flat(memory_arbiter_accessor_memory_ready_flat),
        .accessor_memory_data_size_flat(memory_arbiter_accessor_memory_data_size_flat),
        .accessor_memory_address_flat(memory_arbiter_accessor_memory_address_flat),
        .accessor_memory_data_in_flat(memory_arbiter_accessor_memory_data_in_flat),
        .accessor_memory_data_out_flat(memory_arbiter_accessor_memory_data_out_flat)
    );

    integer i;
    integer j;

    always @(*) begin
        should_halt = 0;

        // Instruction Scheduling

        unoccupied_integer_unit_found = 0;
        unoccupied_integer_unit_index = 0;

        for (i = 0; i < INTEGER_UNIT_COUNT; i = i + 1) begin
            if (!unoccupied_integer_unit_found && !integer_unit_occupied[i]) begin
                unoccupied_integer_unit_found = 1;
                unoccupied_integer_unit_index = i[INTEGER_UNIT_INDEX_SIZE - 1 : 0];
            end
        end

        unoccupied_multiplier_found = 0;
        unoccupied_multiplier_index = 0;

        for (i = 0; i < MULTIPLIER_COUNT; i = i + 1) begin
            if (!unoccupied_multiplier_found && !multiplier_occupied[i]) begin
                unoccupied_multiplier_found = 1;
                unoccupied_multiplier_index = i[MULTIPLIER_INDEX_SIZE - 1 : 0];
            end
        end

        source_1_on_bus = 0;
        source_1_bus_value = 0;
        source_2_on_bus = 0;
        source_2_bus_value = 0;

        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            if (!source_1_on_bus && bus_asserted[i] && bus_source[i] == source_1_source) begin
                source_1_on_bus = 1;
                source_1_bus_value = bus_value[i];
            end

            if (!source_2_on_bus && bus_asserted[i] && bus_source[i] == source_2_source) begin
                source_2_on_bus = 1;
                source_2_bus_value = bus_value[i];
            end
        end

        register_read_index[0] = 0;

        source_1_value = 0;

        if (decoder_source_1_register_index == 0) begin
            source_1_present = 1;
        end else begin
            if (source_1_waiting) begin
                if (source_1_on_bus) begin
                    source_1_present = 1;
                    source_1_value = source_1_bus_value;
                end else begin
                    source_1_present = 0;
                end
            end else begin
                source_1_present = 1;
                register_read_index[0] = decoder_source_1_register_index - 1;
                source_1_value = register_read_data[0];
            end
        end

        register_read_index[1] = 0;

        source_2_value = 0;

        if (decoder_source_2_is_immediate) begin
            source_2_present = 1;
            source_2_value = decoder_source_2_immediate_value;
        end else begin
            if (decoder_source_2_register_index == 0) begin
                source_2_present = 1;
            end else begin
                if (source_2_waiting) begin
                    if (source_2_on_bus) begin
                        source_2_present = 1;
                        source_2_value = source_2_bus_value;
                    end else begin
                        source_2_present = 0;
                    end
                end else begin
                    source_2_present = 1;
                    register_read_index[1] = decoder_source_2_register_index - 1;
                    source_2_value = register_read_data[1];
                end
            end
        end

        if (decoder_destination_register_index != 0) begin
            register_write_index[BUS_COUNT] = decoder_destination_register_index - 1;
        end else begin
            register_write_index[BUS_COUNT] = 0;
        end
        register_write_enable[BUS_COUNT] = 0;
        register_write_data[BUS_COUNT] = 0;

        case (decoder_branch_condition)
            0 : begin // BEQ
                branch_result = source_1_value == source_2_value;
            end

            1 : begin // BNE
                branch_result = source_1_value != source_2_value;
            end

            2 : begin // BLT
                branch_result = $signed(source_1_value) < $signed(source_2_value);
            end

            3 : begin // BGE
                branch_result = $signed(source_1_value) >= $signed(source_2_value);
            end

            4 : begin // BLTU
                branch_result = source_1_value < source_2_value;
            end

            5 : begin // BGEU
                branch_result = source_1_value >= source_2_value;
            end

            default : begin
                branch_result = 0;
            end
        endcase

        if (decoder_jump_and_link_relative) begin
            jump_and_link_destination = (
                decoder_jump_and_link_relative_immediate +
                source_1_value
            ) & ~'b1;
        end else begin
            jump_and_link_destination = instruction_program_counter + decoder_jump_and_link_immediate;
        end

        for (i = 0; i < INTEGER_UNIT_COUNT; i = i + 1) begin
            integer_unit_set_occupied[i] = 0;
        end

        for (i = 0; i < MULTIPLIER_COUNT; i = i + 1) begin
            multiplier_set_occupied[i] = 0;
        end

        memory_unit_set_occupied = 0;

        for (i = 0; i < 31; i = i + 1) begin
            set_register_waiting[i] = 0;
            next_register_station_index[i] = 0;
        end

        load_next_instruction = 0;
        cancel_loading_instruction = 0;
        next_instruction_load_program_counter = 0;

        if (instruction_load_loaded) begin
            if (decoder_valid_instruction) begin
                if (decoder_integer_unit) begin
                    if (decoder_destination_register_index == 0) begin
                        load_next_instruction = 1;
                    end else if (unoccupied_integer_unit_found && !destination_waiting) begin
                        load_next_instruction = 1;

                        integer_unit_set_occupied[unoccupied_integer_unit_index] = 1;

                        set_register_waiting[decoder_destination_register_index - 1] = 1;
                        next_register_station_index[decoder_destination_register_index - 1] = unoccupied_integer_unit_station;
                    end
                end else if (decoder_multiplier) begin
                    if (decoder_destination_register_index == 0) begin
                        load_next_instruction = 1;
                    end else if (unoccupied_multiplier_found && !destination_waiting) begin
                        load_next_instruction = 1;

                        multiplier_set_occupied[unoccupied_multiplier_index] = 1;

                        set_register_waiting[decoder_destination_register_index - 1] = 1;
                        next_register_station_index[decoder_destination_register_index - 1] = unoccupied_multiplier_station;
                    end
                end else if (decoder_load_immediate) begin
                    if (decoder_destination_register_index == 0) begin
                        load_next_instruction = 1;
                    end else if(!destination_waiting) begin
                        load_next_instruction = 1;

                        register_write_enable[BUS_COUNT] = 1;

                        if(decoder_load_immediate_add_instruction_counter) begin
                            register_write_data[BUS_COUNT] = instruction_program_counter + decoder_load_immediate_value;
                        end else begin
                            register_write_data[BUS_COUNT] = decoder_load_immediate_value;
                        end
                    end
                end else if (decoder_branch) begin
                    if (
                        (decoder_source_1_register_index == 0 || !source_1_waiting) &&
                        (decoder_source_2_register_index == 0 || !source_2_waiting)
                    ) begin
                        load_next_instruction = 1;

                        if (branch_result) begin
                            cancel_loading_instruction = 1;

                            if (branch_destination[1 : 0] == 0) begin
                                next_instruction_load_program_counter = branch_destination;
                            end else begin
                                should_halt = 1;
                            end
                        end
                    end
                end else if (decoder_jump_and_link) begin
                    if (decoder_destination_register_index == 0 || !destination_waiting) begin
                        load_next_instruction = 1;
                        cancel_loading_instruction = 1;

                        if (decoder_destination_register_index != 0) begin
                            register_write_enable[BUS_COUNT] = 1;
                            register_write_data[BUS_COUNT] = instruction_program_counter + 4;
                        end

                        if (jump_and_link_destination[1 : 0] == 0) begin
                            next_instruction_load_program_counter = jump_and_link_destination;
                        end else begin
                            should_halt = 1;
                        end
                    end
                end else if (decoder_memory_unit) begin
                    if (decoder_memory_unit_operation == 1) begin
                        load_next_instruction = 1;

                        memory_unit_set_occupied = 1;
                    end else if(decoder_destination_register_index == 0 || !destination_waiting) begin
                        load_next_instruction = 1;

                        memory_unit_set_occupied = 1;

                        if (decoder_destination_register_index != 0) begin
                            set_register_waiting[decoder_destination_register_index - 1] = 1;
                            next_register_station_index[decoder_destination_register_index - 1] = MEMORY_UNIT_STATION;
                        end
                    end
                end else if (decoder_fence) begin
                    if (!memory_unit_occupied) begin
                        load_next_instruction = 1;
                        cancel_loading_instruction = 1;
                        next_instruction_load_program_counter = instruction_load_program_counter;
                    end
                end else begin
                    should_halt = 1;
                end
            end else begin
                should_halt = 1;
            end
        end

        // Register Writeback

        for (i = 0; i < BUS_COUNT; i = i + 1) begin
            register_write_enable[i] = 0;
            register_write_index[i] = 0;
            register_write_data[i] = 0;
        end

        // Only one register can be written to by each bus, and each register can only be written to by one bus
        for (i = 0; i < 31; i = i + 1) begin
            reset_register_waiting[i] = 0;

            for (j = 0; j < BUS_COUNT; j = j + 1) begin
                if (
                    register_waiting[i] &&
                    !reset_register_waiting[i] &&
                    bus_asserted[j] &&
                    bus_source[j] == register_station_index[i] &&
                    !register_write_enable[j]
                ) begin
                    reset_register_waiting[i] = 1;

                    register_write_enable[j] = 1;
                    register_write_index[j] = i[REGISTER_INDEX_SIZE - 1 : 0];
                    register_write_data[j] = bus_value[j];
                end
            end
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            halted <= 0;

            instruction_load_loaded <= 0;
            instruction_load_canceling <= 0;
            instruction_load_program_counter <= 0;
            instruction_load_memory_enable <= 0;

            for (i = 0; i < 31; i = i + 1) begin
                register_waiting[i] <= 0;
            end
        end else if(!halted) begin
            if (should_halt) begin
                halted <= 1;

                `ifdef SIMULATION
                $stop();
                `endif
            end

            // Instruction Load

            if (!instruction_load_memory_enable && !instruction_load_memory_ready) begin
                instruction_load_memory_operation <= 0;
                instruction_load_memory_address <= instruction_load_program_counter;
                instruction_load_memory_data_size <= 2;

                instruction_load_memory_enable <= 1;
            end

            if (instruction_load_memory_enable && instruction_load_memory_ready && !instruction_load_loaded && !instruction_load_canceling && !cancel_loading_instruction) begin
                instruction <= instruction_load_memory_data_in;
                instruction_program_counter <= instruction_load_program_counter;

                instruction_load_memory_enable <= 0;

                instruction_load_loaded <= 1;
                instruction_load_program_counter <= instruction_load_program_counter + 4;
            end

            if (instruction_load_canceling) begin
                if (instruction_load_memory_enable) begin
                    if (instruction_load_memory_ready) begin
                        instruction_load_memory_enable <= 0;

                        instruction_load_canceling <= 0;
                    end
                end else begin
                    instruction_load_canceling <= 0;
                end
            end

            // Instruction Scheduling

            for (i = 0; i < 31; i = i + 1) begin
                if (set_register_waiting[i]) begin
                    register_waiting[i] <= 1;
                    register_station_index[i] <= next_register_station_index[i];
                end else if(reset_register_waiting[i]) begin
                    register_waiting[i] <= 0;
                end
            end

            if (load_next_instruction) begin
                instruction_load_loaded <= 0;
            end

            if (cancel_loading_instruction) begin
                instruction_load_canceling <= 1;
                instruction_load_program_counter <= next_instruction_load_program_counter;
            end
        end
    end
endmodule