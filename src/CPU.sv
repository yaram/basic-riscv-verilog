`default_nettype none

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
    localparam int SIZE = 32;

    localparam int INTEGER_UNIT_COUNT = 4;
    localparam int FIRST_INTEGER_UNIT_STATION = 0;
    localparam int INTEGER_UNIT_INDEX_SIZE = $clog2(INTEGER_UNIT_COUNT);

    localparam int MULTIPLIER_COUNT = 2;
    localparam int FIRST_MULTIPLIER_STATION = INTEGER_UNIT_COUNT;
    localparam int MULTIPLIER_INDEX_SIZE = $clog2(MULTIPLIER_COUNT);

    localparam int MEMORY_UNIT_STATION = FIRST_MULTIPLIER_STATION + MULTIPLIER_COUNT;

    localparam int STATION_COUNT = MEMORY_UNIT_STATION + 1;
    localparam int STATION_INDEX_SIZE = $clog2(STATION_COUNT);

    localparam int BUS_COUNT = 2;
    localparam int BUS_INDEX_SIZE = $clog2(BUS_COUNT);

    localparam int REGISTER_COUNT = 31;
    localparam int REGISTER_INDEX_SIZE = $clog2(REGISTER_COUNT);

    localparam int REGISTER_READ_COUNT = 2;
    localparam int REGISTER_WRITE_COUNT = BUS_COUNT + 1;

    localparam int MEMORY_ACCESSOR_COUNT = 2;

    logic halted;

    logic should_halt;

    logic instruction_load_loaded;
    logic instruction_load_canceling;
    logic [SIZE - 1 : 0]instruction_load_program_counter;
    logic instruction_load_memory_enable;
    logic instruction_load_memory_operation;
    logic instruction_load_memory_ready;
    logic [1 : 0]instruction_load_memory_data_size;
    logic [SIZE - 1 : 0]instruction_load_memory_address;
    logic [SIZE - 1 : 0]instruction_load_memory_data_in;

    assign memory_arbiter_accessor_memory_enable[1] = instruction_load_memory_enable;
    assign memory_arbiter_accessor_memory_operation[1] = instruction_load_memory_operation;
    assign instruction_load_memory_ready = memory_arbiter_accessor_memory_ready[1];
    assign memory_arbiter_accessor_memory_data_size[1] = instruction_load_memory_data_size;
    assign memory_arbiter_accessor_memory_address[1] = instruction_load_memory_address;
    assign instruction_load_memory_data_in = memory_arbiter_accessor_memory_data_in[1];
    assign memory_arbiter_accessor_memory_data_out[1] = 0;

    logic [31 : 0]instruction;
    logic [SIZE - 1 : 0]instruction_program_counter;

    logic decoder_valid_instruction;
    logic [4 : 0]decoder_source_1_register_index;
    logic decoder_source_2_is_immediate;
    logic [4 : 0]decoder_source_2_register_index;
    logic [31 : 0]decoder_source_2_immediate_value;
    logic [4 : 0]decoder_destination_register_index;
    logic decoder_integer_unit;
    logic [3 : 0]decoder_integer_unit_operation;
    logic decoder_multiplier;
    logic [1 : 0]decoder_multiplier_operation;
    logic decoder_multiplier_source_1_signed;
    logic decoder_multiplier_source_2_signed;
    logic decoder_multiplier_upper_result;
    logic decoder_load_immediate;
    logic decoder_load_immediate_add_instruction_counter;
    logic [31 : 0]decoder_load_immediate_value;
    logic decoder_branch;
    logic [2 : 0]decoder_branch_condition;
    logic [31 : 0]decoder_branch_immediate;
    logic decoder_jump_and_link;
    logic decoder_jump_and_link_relative;
    logic [31 : 0]decoder_jump_and_link_immediate;
    logic [31 : 0]decoder_jump_and_link_relative_immediate;
    logic decoder_memory_unit;
    logic decoder_memory_unit_operation;
    logic [1 : 0]decoder_memory_unit_data_size;
    logic decoder_memory_unit_signed;
    logic [31 : 0]decoder_memory_unit_address_offset_immediate;
    logic decoder_fence;

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

    logic load_next_instruction;
    logic cancel_loading_instruction;
    logic [SIZE - 1 : 0]next_instruction_load_program_counter;
    logic set_register_waiting[0 : 30];
    logic [STATION_INDEX_SIZE - 1 : 0]next_register_station_index[0 : 30];
    logic reset_register_waiting[0 : 30];

    logic unoccupied_integer_unit_found;
    logic [INTEGER_UNIT_INDEX_SIZE - 1 : 0]unoccupied_integer_unit_index;
    logic [STATION_INDEX_SIZE - 1 : 0]unoccupied_integer_unit_station = FIRST_INTEGER_UNIT_STATION + {{(STATION_INDEX_SIZE -  INTEGER_UNIT_INDEX_SIZE){1'b0}}, unoccupied_integer_unit_index};
    logic unoccupied_multiplier_found;
    logic [MULTIPLIER_INDEX_SIZE - 1 : 0]unoccupied_multiplier_index;
    logic [STATION_INDEX_SIZE - 1 : 0]unoccupied_multiplier_station = FIRST_MULTIPLIER_STATION + {{(STATION_INDEX_SIZE -  MULTIPLIER_INDEX_SIZE){1'b0}}, unoccupied_multiplier_index};
    logic source_1_on_bus;
    logic [SIZE - 1 : 0]source_1_bus_value;
    logic source_2_on_bus;
    logic [SIZE - 1 : 0]source_2_bus_value;
    logic [SIZE - 1 : 0]branch_destination = instruction_program_counter + decoder_branch_immediate;
    logic branch_result;
    logic [SIZE - 1 : 0]jump_and_link_destination;

    logic bus_asserted[0 : BUS_COUNT - 1];
    logic [STATION_INDEX_SIZE - 1 : 0]bus_source[0 : BUS_COUNT - 1];
    logic [SIZE - 1 : 0]bus_value[0 : BUS_COUNT - 1];

    logic register_waiting[0 : 30];
    logic [STATION_INDEX_SIZE - 1 : 0]register_station_index[0 : 30];

    logic [REGISTER_INDEX_SIZE - 1 : 0]register_read_index[0 : REGISTER_READ_COUNT - 1];
    logic [SIZE - 1 : 0]register_read_data[0 : REGISTER_READ_COUNT - 1];
    logic register_write_enable[0 : REGISTER_WRITE_COUNT - 1];
    logic [REGISTER_INDEX_SIZE - 1 : 0]register_write_index[0 : REGISTER_WRITE_COUNT - 1];
    logic [SIZE - 1 : 0]register_write_data[0 : REGISTER_WRITE_COUNT - 1];

    RegisterFile #(
        .SIZE(SIZE),
        .REGISTER_COUNT(31),
        .READ_COUNT(REGISTER_READ_COUNT),
        .WRITE_COUNT(REGISTER_WRITE_COUNT)
    ) register_file (
        .clock(clock),
        .reset(reset),
        .read_index(register_read_index),
        .read_data(register_read_data),
        .write_enable(register_write_enable),
        .write_index(register_write_index),
        .write_data(register_write_data)
    );

    logic source_1_present;
    logic [STATION_INDEX_SIZE - 1 : 0]source_1_source = register_station_index[decoder_source_1_register_index - 1];
    logic source_1_waiting = register_waiting[decoder_source_1_register_index - 1];
    logic [SIZE - 1 : 0]source_1_value;
    logic source_2_present;
    logic [STATION_INDEX_SIZE - 1 : 0]source_2_source = register_station_index[decoder_source_2_register_index - 1];
    logic source_2_waiting = register_waiting[decoder_source_2_register_index - 1];
    logic [SIZE - 1 : 0]source_2_value;
    logic destination_waiting = register_waiting[decoder_destination_register_index - 1];

    logic integer_unit_set_occupied[0 : INTEGER_UNIT_COUNT - 1];
    logic integer_unit_occupied[0 : INTEGER_UNIT_COUNT - 1];

    generate
        for (genvar i = 0; i < INTEGER_UNIT_COUNT; i += 1) begin
            IntegerUnit #(
                .SIZE(SIZE),
                .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
                .BUS_COUNT(BUS_COUNT)
            ) integer_unit (
                .clock(clock),
                .reset(reset),
                .set_occupied(integer_unit_set_occupied[i]),
                .reset_occupied(station_is_asserting[FIRST_INTEGER_UNIT_STATION + i]),
                .operation(decoder_integer_unit_operation),
                .preload_a_value(source_1_present),
                .a_source(source_1_source),
                .preloaded_a_value(source_1_value),
                .preload_b_value(source_2_present),
                .b_source(source_2_source),
                .preloaded_b_value(source_2_value),
                .occupied(integer_unit_occupied[i]),
                .result_ready(station_ready[FIRST_INTEGER_UNIT_STATION + i]),
                .result(station_value[FIRST_INTEGER_UNIT_STATION + i]),
                .bus_asserted(bus_asserted),
                .bus_source(bus_source),
                .bus_value(bus_value)
            );
        end
    endgenerate

    logic multiplier_set_occupied[0 : MULTIPLIER_COUNT - 1];
    logic multiplier_occupied[0 : MULTIPLIER_COUNT - 1];

    generate
        for (genvar i = 0; i < MULTIPLIER_COUNT; i += 1) begin
            Multiplier #(
                .SIZE(SIZE),
                .STATION_INDEX_SIZE(STATION_INDEX_SIZE),
                .BUS_COUNT(BUS_COUNT)
            ) multiplier (
                .clock(clock),
                .reset(reset),
                .set_occupied(multiplier_set_occupied[i]),
                .reset_occupied(station_is_asserting[FIRST_MULTIPLIER_STATION + i]),
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
                .occupied(multiplier_occupied[i]),
                .result_ready(station_ready[FIRST_MULTIPLIER_STATION + i]),
                .result(station_value[FIRST_MULTIPLIER_STATION + i]),
                .bus_asserted(bus_asserted),
                .bus_source(bus_source),
                .bus_value(bus_value)
            );
        end
    endgenerate

    logic memory_unit_set_occupied;
    logic memory_unit_occupied;

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
        .bus_asserted(bus_asserted),
        .bus_source(bus_source),
        .bus_value(bus_value),
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
        .bus_asserted(bus_asserted),
        .bus_source(bus_source),
        .bus_value(bus_value),
        .station_ready(station_ready),
        .station_value(station_value),
        .station_is_asserting(station_is_asserting)
    );

    logic memory_arbiter_accessor_memory_enable[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic memory_arbiter_accessor_memory_operation[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic memory_arbiter_accessor_memory_ready[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic [1 : 0]memory_arbiter_accessor_memory_data_size[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic [SIZE - 1 : 0]memory_arbiter_accessor_memory_address[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic [SIZE - 1 : 0]memory_arbiter_accessor_memory_data_in[0 : MEMORY_ACCESSOR_COUNT - 1];
    logic [SIZE - 1 : 0]memory_arbiter_accessor_memory_data_out[0 : MEMORY_ACCESSOR_COUNT - 1];

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
        .accessor_memory_enable(memory_arbiter_accessor_memory_enable),
        .accessor_memory_operation(memory_arbiter_accessor_memory_operation),
        .accessor_memory_ready(memory_arbiter_accessor_memory_ready),
        .accessor_memory_data_size(memory_arbiter_accessor_memory_data_size),
        .accessor_memory_address(memory_arbiter_accessor_memory_address),
        .accessor_memory_data_in(memory_arbiter_accessor_memory_data_in),
        .accessor_memory_data_out(memory_arbiter_accessor_memory_data_out)
    );

    always_comb begin
        should_halt = 0;

        // Instruction Scheduling

        unoccupied_integer_unit_found = 0;
        unoccupied_integer_unit_index = 0;

        for (int i = 0; i < INTEGER_UNIT_COUNT; i += 1) begin
            if (!unoccupied_integer_unit_found && !integer_unit_occupied[i]) begin
                unoccupied_integer_unit_found = 1;
                unoccupied_integer_unit_index = i[INTEGER_UNIT_INDEX_SIZE - 1 : 0];
            end
        end

        unoccupied_multiplier_found = 0;
        unoccupied_multiplier_index = 0;

        for (int i = 0; i < MULTIPLIER_COUNT; i += 1) begin
            if (!unoccupied_multiplier_found && !multiplier_occupied[i]) begin
                unoccupied_multiplier_found = 1;
                unoccupied_multiplier_index = i[MULTIPLIER_INDEX_SIZE - 1 : 0];
            end
        end

        source_1_on_bus = 0;
        source_1_bus_value = 0;
        source_2_on_bus = 0;
        source_2_bus_value = 0;

        for (int i = 0; i < BUS_COUNT; i += 1) begin
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

        for (int i = 0; i < INTEGER_UNIT_COUNT; i += 1) begin
            integer_unit_set_occupied[i] = 0;
        end

        for (int i = 0; i < MULTIPLIER_COUNT; i += 1) begin
            multiplier_set_occupied[i] = 0;
        end

        memory_unit_set_occupied = 0;

        for (int i = 0; i < 31; i += 1) begin
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

        for (int i = 0; i < BUS_COUNT; i += 1) begin
            register_write_enable[i] = 0;
            register_write_index[i] = 0;
            register_write_data[i] = 0;
        end

        // Only one register can be written to by each bus, and each register can only be written to by one bus
        for (int i = 0; i < 31; i += 1) begin
            reset_register_waiting[i] = 0;

            for (int j = 0; j < BUS_COUNT; j += 1) begin
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

    always_ff @(posedge clock) begin
        if (reset) begin
            halted <= 0;

            instruction_load_loaded <= 0;
            instruction_load_canceling <= 0;
            instruction_load_program_counter <= 0;
            instruction_load_memory_enable <= 0;

            for (int i = 0; i < 31; i += 1) begin
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

            for (int i = 0; i < 31; i += 1) begin
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