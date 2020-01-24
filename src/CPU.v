module CPU(
    input wire clock,
    input wire reset,
    output reg [31 : 0]memory_address,
    input wire [31 : 0]memory_data_in,
    output reg [31 : 0]memory_data_out,
    output reg [1 : 0]memory_data_size,
    output reg memory_enable,
    output reg memory_operation,
    input wire memory_ready
);
    reg halted;

    reg instruction_load_waiting;
    reg instruction_load_loaded;
    reg instruction_load_canceling;
    reg [31 : 0]instruction_load_program_counter;

    reg [31 : 0]instruction;
    reg [31 : 0]instruction_program_counter;

    wire [6 : 0]opcode = instruction[6 : 0];

    wire [2 : 0]function_3 = instruction[14 : 12];
    wire [6 : 0]function_7 = instruction[31 : 25];

    wire [4 : 0]source_1_register_index = instruction[19 : 15];
    wire [4 : 0]source_2_register_index = instruction[24 : 20];
    wire [4 : 0]destination_register_index = instruction[11 : 7];
    
    wire [31 : 0]source_1_register_value = source_1_register_index == 0 ? 0 : register_values[source_1_register_index - 1];
    wire [31 : 0]source_2_register_value = source_2_register_index == 0 ? 0 : register_values[source_2_register_index - 1];

    wire [31 : 0]immediate = {{21{instruction[31]}}, instruction[30 : 20]};
    wire [31 : 0]immediate_store = {{21{instruction[31]}}, instruction[30 : 25], instruction[11 : 7]};
    wire [31 : 0]immediate_branch = {{20{instruction[31]}}, instruction[7], instruction[30 : 25], instruction[11 : 8], 1'b0};
    wire [31 : 0]immediate_upper = instruction[31 : 12];
    wire [31 : 0]immediate_jump = {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0};

    parameter alu_count = 4;
    parameter alu_index_size = 2; // $bits(alu_count - 1)

    parameter memory_unit_count = 1;

    parameter station_count = alu_count + memory_unit_count;
    parameter station_index_size = 3; // $bits(station_count - 1)

    reg register_busy_states[0 : 30];
    reg [station_index_size - 1 : 0]register_station_indices[0 : 30];
    reg [31 : 0]register_values[0 : 30];

    reg [4 : 0]alu_operations[0 : alu_count - 1];
    reg alu_occupied_states[0 : alu_count - 1];
    reg [station_index_size - 1 : 0]alu_source_1_indices[0 : alu_count - 1];
    reg [station_index_size - 1 : 0]alu_source_2_indices[0 : alu_count - 1];
    reg alu_source_1_loaded_states[0 : alu_count - 1];
    reg alu_source_2_loaded_states[0 : alu_count - 1];
    reg [31 : 0]alu_source_1_values[0 : alu_count - 1];
    reg [31 : 0]alu_source_2_values[0 : alu_count - 1];

    reg memory_unit_occupied;
    reg memory_unit_waiting;
    reg memory_unit_operation;
    reg memory_unit_address_loaded;
    reg [station_index_size - 1 : 0]memory_unit_address_index;
    reg [31 : 0]memory_unit_address_value;
    reg [31 : 0]memory_unit_address_offset;
    reg [1 : 0]memory_unit_data_size;
    reg memory_unit_signed;
    reg [station_index_size - 1 : 0]memory_unit_source_index;
    reg memory_unit_source_loaded;
    reg [31 : 0]memory_unit_source_value;

    reg bus_asserted;
    reg [station_index_size - 1 : 0]bus_source;
    reg [31 : 0]bus_value;

    integer i;

    reg unoccupied_alu_found;

    reg bus_to_be_asserted;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            $display("Reset");

            memory_enable <= 0;

            halted <= 0;

            instruction_load_waiting <= 0;
            instruction_load_loaded <= 0;
            instruction_load_canceling <= 0;
            instruction_load_program_counter <= 0;

            for (i = 0; i < 31; i = i + 1) begin
                register_busy_states[i] <= 0;
            end

            for (i = 0; i < alu_count; i = i + 1) begin
                alu_occupied_states[i] <= 0;
            end

            memory_unit_occupied <= 0;
            memory_unit_waiting <= 0;

            bus_asserted <= 0;
        end else if(!halted) begin
            `ifdef VERBOSE
            $display("PC: %h", instruction_load_program_counter);

            for (i = 0; i < 31; i = i + 1) begin
                $display("Reg %d: %d, %d, %d", i + 1, register_busy_states[i], register_station_indices[i], register_values[i]);
            end

            for (i = 0; i < alu_count; i = i + 1) begin
                $display("ALU %d: %d", i, alu_occupied_states[i]);
                $display("    Source 1: %d, %d, %d", i, alu_source_1_loaded_states[i], alu_source_1_indices[i], alu_source_1_values[i]);
                $display("    Source 2: %d, %d, %d", i, alu_source_2_loaded_states[i], alu_source_2_indices[i], alu_source_2_values[i]);
            end

            $display("Memory: %d, %d, %d", memory_unit_occupied, memory_unit_operation, memory_unit_waiting);
            $display("    Address: %d, %d, %h", memory_unit_address_loaded, memory_unit_address_index, memory_unit_address_value);
            $display("    Value: %d, %d, %d", memory_unit_source_loaded, memory_unit_source_index, memory_unit_source_value);

            $display("Bus: %d, %d, %d", bus_asserted, bus_source, bus_value);
            `endif

            // Instruction Load

            if (!memory_ready && !instruction_load_waiting && !instruction_load_canceling && !memory_unit_occupied) begin
                $display("Instruction Load Begin");

                memory_operation <= 0;
                memory_address <= instruction_load_program_counter;
                memory_data_size <= 2;

                memory_enable <= 1;

                instruction_load_waiting <= 1;
            end

            if (memory_ready && instruction_load_waiting && !instruction_load_loaded && !instruction_load_canceling) begin
                $display("Instruction Load End");

                instruction <= memory_data_in;
                instruction_program_counter <= instruction_load_program_counter;

                memory_enable <= 0;

                instruction_load_waiting <= 0;
                instruction_load_loaded <= 1;
                instruction_load_program_counter <= instruction_load_program_counter + 4;
            end

            if (instruction_load_canceling) begin
                if (instruction_load_waiting) begin
                    if (memory_ready) begin
                        memory_enable <= 0;

                        instruction_load_waiting <= 0;
                        instruction_load_canceling <= 0;
                    end
                end else begin
                    instruction_load_canceling <= 0;
                end
            end

            // Instruction Decoding

            if (instruction_load_loaded) begin
                case (opcode[1 : 0])
                    2'b11: begin // Base instruction set
                        case (opcode[6 : 2])
                            5'b00100 : begin // OP-IMM
                                if (destination_register_index != 0) begin
                                    unoccupied_alu_found = 0;

                                    for (i = 0; i < alu_count; i = i + 1) begin
                                        if (!unoccupied_alu_found && !alu_occupied_states[i]) begin
                                            unoccupied_alu_found = 1;

                                            instruction_load_loaded <= 0;
                                            alu_occupied_states[i] <= 1;

                                            if (source_1_register_index == 0) begin
                                                alu_source_1_loaded_states[i] <= 1;
                                                alu_source_1_values[i] <= 0;
                                            end else begin
                                                if (register_busy_states[source_1_register_index - 1]) begin
                                                    if (bus_asserted && bus_source == register_station_indices[source_1_register_index - 1]) begin
                                                        alu_source_1_loaded_states[i] <= 1;
                                                        alu_source_1_values[i] <= bus_value;
                                                    end else begin
                                                        alu_source_1_loaded_states[i] <= 0;
                                                        alu_source_1_indices[i] <= register_station_indices[source_1_register_index - 1];
                                                    end
                                                end else begin
                                                    alu_source_1_loaded_states[i] <= 1;
                                                    alu_source_1_values[i] <= register_values[source_1_register_index - 1];
                                                end
                                            end

                                            alu_source_2_loaded_states[i] <= 1;
                                            alu_source_2_values[i] <= immediate;

                                            register_busy_states[destination_register_index - 1] <= 1;
                                            register_station_indices[destination_register_index - 1] <= i;

                                            case (function_3)
                                                3'b000 : begin // ADDI
                                                    $display("addi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                                    alu_operations[i] <= 0;
                                                end

                                                3'b010 : begin // SLTI
                                                    $display("slti x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                                    alu_operations[i] <= 9;
                                                end

                                                3'b011 : begin // SLTIU
                                                    $display("sltiu x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                                    alu_operations[i] <= 8;
                                                end

                                                3'b100 : begin // XORI
                                                    $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                                    alu_operations[i] <= 4;
                                                end

                                                3'b110 : begin // ORI
                                                    $display("ori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                                    alu_operations[i] <= 2;
                                                end

                                                3'b111 : begin // ANDI
                                                    $display("andi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                                    alu_operations[i] <= 3;
                                                end

                                                3'b001 : begin // SLLI
                                                    $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                                    alu_operations[i] <= 5;
                                                end

                                                3'b101 : begin
                                                    if (instruction[30] == 0) begin // SRLI
                                                        $display("srli x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                                        alu_operations[i] <= 6;
                                                    end else begin // SRAI
                                                        $display("srai x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                                        alu_operations[i] <= 7;
                                                    end
                                                end

                                                default : begin
                                                    $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                                    halted <= 1;

                                                    $stop();
                                                end
                                            endcase
                                        end
                                    end
                                end else begin
                                    instruction_load_loaded <= 0;

                                    case (function_3)
                                        3'b000 : begin // ADDI
                                            $display("addi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));
                                        end

                                        3'b010 : begin // SLTI
                                            $display("slti x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));
                                        end

                                        3'b011 : begin // SLTIU
                                            $display("sltiu x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);
                                        end

                                        3'b100 : begin // XORI
                                            $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);
                                        end

                                        3'b110 : begin // ORI
                                            $display("ori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);
                                        end

                                        3'b111 : begin // ANDI
                                            $display("andi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);
                                        end

                                        3'b001 : begin // SLLI
                                            $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);
                                        end

                                        3'b101 : begin
                                            if (instruction[30] == 0) begin // SRLI
                                                $display("srli x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);
                                            end else begin // SRAI
                                                $display("srai x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);
                                            end
                                        end

                                        default : begin
                                            $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                            halted <= 1;

                                            $stop();
                                        end
                                    endcase
                                end
                            end

                            5'b01100 : begin // OP
                                if (destination_register_index != 0) begin
                                    unoccupied_alu_found = 0;

                                    for (i = 0; i < alu_count; i = i + 1) begin
                                        if (!unoccupied_alu_found && !alu_occupied_states[i]) begin
                                            unoccupied_alu_found = 1;

                                            instruction_load_loaded <= 0;
                                            alu_occupied_states[i] <= 1;

                                            if (source_1_register_index == 0) begin
                                                alu_source_1_loaded_states[i] <= 1;
                                                alu_source_1_values[i] <= 0;
                                            end else begin
                                                if (register_busy_states[source_1_register_index - 1]) begin
                                                    if (bus_asserted && bus_source == register_station_indices[source_1_register_index - 1]) begin
                                                        alu_source_1_loaded_states[i] <= 1;
                                                        alu_source_1_values[i] <= bus_value;
                                                    end else begin
                                                        alu_source_1_loaded_states[i] <= 0;
                                                        alu_source_1_indices[i] <= register_station_indices[source_1_register_index - 1];
                                                    end
                                                end else begin
                                                    alu_source_1_loaded_states[i] <= 1;
                                                    alu_source_1_values[i] <= register_values[source_1_register_index - 1];
                                                end
                                            end

                                            if (source_2_register_index == 0) begin
                                                alu_source_2_loaded_states[i] <= 1;
                                                alu_source_2_values[i] <= 0;
                                            end else begin
                                                if (register_busy_states[source_2_register_index - 1]) begin
                                                    if (bus_asserted && bus_source == register_station_indices[source_2_register_index - 1]) begin
                                                        alu_source_2_loaded_states[i] <= 1;
                                                        alu_source_2_values[i] <= bus_value;
                                                    end else begin
                                                        alu_source_2_loaded_states[i] <= 0;
                                                        alu_source_2_indices[i] <= register_station_indices[source_2_register_index - 1];
                                                    end
                                                end else begin
                                                    alu_source_2_loaded_states[i] <= 1;
                                                    alu_source_2_values[i] <= register_values[source_2_register_index - 1];
                                                end
                                            end

                                            register_busy_states[destination_register_index - 1] <= 1;
                                            register_station_indices[destination_register_index - 1] <= i;

                                            case (function_3)
                                                3'b000 : begin
                                                    if (instruction[30] == 0) begin // ADD
                                                        $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                        alu_operations[i] <= 0;
                                                    end else begin // SUB
                                                        $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                        alu_operations[i] <= 1;
                                                    end
                                                end

                                                3'b010 : begin // SLT
                                                    $display("slt x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 9;
                                                end

                                                3'b011 : begin // SLTU
                                                    $display("sltu x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 8;
                                                end

                                                3'b100 : begin // XOR
                                                    $display("xor x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 4;
                                                end

                                                3'b110 : begin // OR
                                                    $display("or x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 2;
                                                end

                                                3'b111 : begin // AND
                                                    $display("and x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 3;
                                                end

                                                3'b001 : begin // SLL
                                                    $display("sll x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                    alu_operations[i] <= 5;
                                                end

                                                3'b101 : begin
                                                    if (instruction[30] == 0) begin // SRL
                                                        $display("srl x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                        alu_operations[i] <= 6;
                                                    end else begin // SRA
                                                        $display("sra x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                                        alu_operations[i] <= 7;
                                                    end
                                                end

                                                default : begin
                                                    $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                                    halted <= 1;

                                                    $stop();
                                                end
                                            endcase
                                        end
                                    end
                                end else begin
                                    instruction_load_loaded <= 0;

                                    case (function_3)
                                        3'b000 : begin
                                            if (instruction[30] == 0) begin // ADD
                                                $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                            end else begin // SUB
                                                $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                            end
                                        end

                                        3'b010 : begin // SLT
                                            $display("slt x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b011 : begin // SLTU
                                            $display("sltu x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b100 : begin // XOR
                                            $display("xor x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b110 : begin // OR
                                            $display("or x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b111 : begin // AND
                                            $display("and x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b001 : begin // SLL
                                            $display("sll x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                        end

                                        3'b101 : begin
                                            if (instruction[30] == 0) begin // SRL
                                                $display("srl x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                            end else begin // SRA
                                                $display("sra x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);
                                            end
                                        end

                                        default : begin
                                            $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                            halted <= 1;

                                            $stop();
                                        end
                                    endcase
                                end
                            end

                            5'b00101 : begin // AUIPC
                                $display("auipc x%0d, %0d", destination_register_index, immediate_upper);

                                if (destination_register_index != 0) begin
                                    register_values[destination_register_index - 1] <= instruction_program_counter + {immediate_upper, 12'b0};
                                end

                                instruction_load_loaded <= 0;
                            end

                            5'b01101 : begin // LUI
                                $display("lui x%0d, %0d", destination_register_index, immediate_upper);

                                if (destination_register_index != 0) begin
                                    register_values[destination_register_index - 1] <= {immediate_upper, 12'b0};
                                end

                                instruction_load_loaded <= 0;
                            end

                            5'b11000 : begin // BRANCH
                                if (
                                    (source_1_register_index == 0 || !register_busy_states[source_1_register_index - 1]) &&
                                    (source_2_register_index == 0 || !register_busy_states[source_2_register_index - 1])
                                ) begin
                                    instruction_load_loaded <= 0;

                                    case (function_3)
                                        3'b000 : begin // BEQ
                                            $display("beq x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);

                                            if (source_1_register_value == source_2_register_value) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        3'b001 : begin // BNE
                                            $display("bne x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);

                                            if (source_1_register_value != source_2_register_value) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        3'b100 : begin // BLT
                                            $display("blt x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);

                                            if ($signed(source_1_register_value) < $signed(source_2_register_value)) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        3'b101 : begin // BGE
                                            $display("bge x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);
                                            
                                            if ($signed(source_1_register_value) >= $signed(source_2_register_value)) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        3'b110 : begin // BLTU
                                            $display("bltu x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);
                                            
                                            if (source_1_register_value < source_2_register_value) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        3'b111 : begin // BGEU
                                            $display("bgeu x%0d, x%0d, %0d", source_1_register_index, source_2_register_index, immediate_branch);
                                            
                                            if (source_1_register_value >= source_2_register_value) begin
                                                instruction_load_program_counter <= instruction_program_counter + immediate_branch;

                                                instruction_load_canceling <= 1;
                                            end
                                        end

                                        default : begin
                                            $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                            halted <= 1;

                                            $stop();
                                        end
                                    endcase
                                end
                            end

                            5'b11011 : begin // JAL
                                if (destination_register_index == 0 || !register_busy_states[destination_register_index - 1]) begin
                                    $display("jal x%0d, %0d", destination_register_index, $signed(immediate_jump));

                                    if (destination_register_index != 0) begin
                                        register_values[destination_register_index - 1] <= instruction_program_counter + 4;
                                    end

                                    instruction_load_program_counter <= instruction_program_counter + immediate_jump;

                                    instruction_load_canceling <= 1;

                                    instruction_load_loaded <= 0;
                                end
                            end

                            5'b11001 : begin // JALR
                                if (
                                    (destination_register_index == 0 || !register_busy_states[destination_register_index - 1]) &&
                                    (source_1_register_index == 0 || !register_busy_states[source_1_register_index - 1])
                                ) begin
                                    $display("jalr x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                    if (destination_register_index != 0) begin
                                        register_values[destination_register_index - 1] <= instruction_program_counter + 4;
                                    end

                                    if (source_1_register_index == 0) begin
                                        instruction_load_program_counter <= immediate & ~32'b1;
                                    end else begin
                                        instruction_load_program_counter <= (immediate + register_values[source_1_register_index - 1]) & ~32'b1;
                                    end

                                    instruction_load_canceling <= 1;
                                    instruction_load_loaded <= 0;
                                end
                            end

                            5'b00000 : begin // LOAD
                                if (memory_unit_occupied == 0) begin
                                    instruction_load_loaded <= 0;

                                    memory_unit_occupied <= 1;
                                    memory_unit_operation <= 0;

                                    if (source_1_register_index == 0) begin
                                        memory_unit_address_loaded <= 1;
                                        memory_unit_address_value <= 0;
                                    end else begin
                                        if (register_busy_states[source_1_register_index - 1]) begin
                                            if (bus_asserted && bus_source == register_station_indices[source_1_register_index - 1]) begin
                                                memory_unit_address_loaded <= 1;
                                                memory_unit_address_value <= bus_value;
                                            end else begin
                                                memory_unit_address_loaded <= 0;
                                                memory_unit_address_index <= register_station_indices[source_1_register_index - 1];
                                            end
                                        end else begin
                                            memory_unit_address_loaded <= 1;
                                            memory_unit_address_value <= register_values[source_1_register_index - 1];
                                        end
                                    end
                                    memory_unit_address_offset <= immediate;

                                    if (destination_register_index != 0) begin
                                        register_busy_states[destination_register_index - 1] <= 1;
                                        register_station_indices[destination_register_index - 1] <= i;
                                    end

                                    case (function_3)
                                        3'b000 : begin // LB
                                            $display("lb x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_unit_data_size <= 0;
                                            memory_unit_signed <= 1;
                                        end

                                        3'b001 : begin // LH
                                            $display("lh x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_unit_data_size <= 1;
                                            memory_unit_signed <= 1;
                                        end

                                        3'b010 : begin // LW
                                            $display("lw x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_unit_data_size <= 2;
                                            memory_unit_signed <= 1;
                                        end

                                        3'b100 : begin // LBU
                                            $display("lbu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_unit_data_size <= 0;
                                            memory_unit_signed <= 0;
                                        end

                                        3'b101 : begin // LWU
                                            $display("lhu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_unit_data_size <= 0;
                                            memory_unit_signed <= 0;
                                        end
                                    endcase
                                end
                            end

                            5'b01000 : begin // STORE
                                if (memory_unit_occupied == 0) begin
                                    instruction_load_loaded <= 0;

                                    memory_unit_occupied <= 1;
                                    memory_unit_operation <= 1;

                                    if (source_1_register_index == 0) begin
                                        memory_unit_address_loaded <= 1;
                                        memory_unit_address_value <= 0;
                                    end else begin
                                        if (register_busy_states[source_1_register_index - 1]) begin
                                            if (bus_asserted && bus_source == register_station_indices[source_1_register_index - 1]) begin
                                                memory_unit_address_loaded <= 1;
                                                memory_unit_address_value <= bus_value;
                                            end else begin
                                                memory_unit_address_loaded <= 0;
                                                memory_unit_address_index <= register_station_indices[source_1_register_index - 1];
                                            end
                                        end else begin
                                            memory_unit_address_loaded <= 1;
                                            memory_unit_address_value <= register_values[source_1_register_index - 1];
                                        end
                                    end
                                    memory_unit_address_offset <= immediate_store;

                                    if (source_2_register_index == 0) begin
                                        memory_unit_source_loaded <= 1;
                                        memory_unit_source_value <= 0;
                                    end else begin
                                        if (register_busy_states[source_2_register_index - 1]) begin
                                            if (bus_asserted && bus_source == register_station_indices[source_2_register_index - 1]) begin
                                                memory_unit_source_loaded <= 1;
                                                memory_unit_source_value <= bus_value;
                                            end else begin
                                                memory_unit_source_loaded <= 0;
                                                memory_unit_source_index <= register_station_indices[source_2_register_index - 1];
                                            end
                                        end else begin
                                            memory_unit_source_loaded <= 1;
                                            memory_unit_source_value <= register_values[source_2_register_index - 1];
                                        end
                                    end

                                    case (function_3)
                                        3'b000 : begin // SB
                                            $display("sb x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_unit_data_size <= 0;
                                        end

                                        3'b001 : begin // SH
                                            $display("sh x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_unit_data_size <= 1;
                                        end

                                        3'b010 : begin // SW
                                            $display("sw x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_unit_data_size <= 2;
                                        end

                                        default : begin
                                            $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                            halted <= 1;

                                            $stop();
                                        end
                                    endcase
                                end
                            end

                            default : begin
                                $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                                halted <= 1;

                                $stop();
                            end
                        endcase
                    end

                    default : begin
                        $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);

                        halted <= 1;

                        $stop();
                    end
                endcase
            end

            bus_to_be_asserted = 0;

            // Instruction Execution (ALUs)

            for (i = 0; i < 31; i = i + 1) begin
                if (register_busy_states[i] && bus_asserted && bus_source == register_station_indices[i]) begin
                    register_busy_states[i] <= 0;
                    register_values[i] <= bus_value;
                end
            end

            for (i = 0; i < alu_count; i = i + 1) begin
                if (alu_occupied_states[i]) begin
                    if (bus_asserted) begin
                        if (!alu_source_1_loaded_states[i] && bus_source == alu_source_1_indices[i]) begin
                            alu_source_1_loaded_states[i] <= 1;
                            alu_source_1_values[i] <= bus_value;
                        end

                        if (!alu_source_2_loaded_states[i] && bus_source == alu_source_2_indices[i]) begin
                            alu_source_2_loaded_states[i] <= 1;
                            alu_source_2_values[i] <= bus_value;
                        end

                        if (bus_source == i) begin
                            bus_asserted <= 0;
                            alu_occupied_states[i] <= 0;
                        end
                    end else if (alu_source_1_loaded_states[i] && alu_source_2_loaded_states[i] && !bus_to_be_asserted) begin
                        bus_source <= i;
                        bus_asserted <= 1;

                        bus_to_be_asserted = 1;

                        case (alu_operations[i])
                            0 : begin
                                bus_value <= alu_source_1_values[i] + alu_source_2_values[i];
                            end

                            1 : begin
                                bus_value <= alu_source_1_values[i] - alu_source_2_values[i];
                            end

                            2 : begin
                                bus_value <= alu_source_1_values[i] | alu_source_2_values[i];
                            end

                            3 : begin
                                bus_value <= alu_source_1_values[i] & alu_source_2_values[i];
                            end

                            4 : begin
                                bus_value <= alu_source_1_values[i] ^ alu_source_2_values[i];
                            end

                            5 : begin
                                bus_value <= alu_source_1_values[i] << alu_source_2_values[i];
                            end

                            6 : begin
                                bus_value <= alu_source_1_values[i] >> alu_source_2_values[i];
                            end

                            7 : begin
                                bus_value <= alu_source_1_values[i] >>> alu_source_2_values[i];
                            end

                            8 : begin
                                bus_value <= alu_source_1_values[i] < alu_source_2_values[i];
                            end

                            9 : begin
                                bus_value <= $signed(alu_source_1_values[i]) < $signed(alu_source_2_values[i]);
                            end
                        endcase
                    end
                end
            end

            // Memory Load & Store

            if (memory_unit_occupied) begin
                if (bus_asserted && bus_source == station_count - 1) begin
                    bus_asserted <= 0;

                    memory_unit_occupied <= 0;
                end else begin
                    if (!memory_unit_waiting) begin
                        if (!memory_unit_address_loaded && bus_asserted && bus_source == memory_unit_address_index) begin
                            memory_unit_address_loaded <= 1;
                            memory_unit_address_value <= bus_value;
                        end

                        if (memory_unit_operation == 1 && !memory_unit_source_loaded && bus_asserted && bus_source == memory_unit_source_index) begin
                            memory_unit_source_loaded <= 1;
                            memory_unit_source_value <= bus_value;
                        end

                        if (!memory_ready && memory_unit_address_loaded && (memory_unit_operation == 0 || memory_unit_source_loaded)) begin
                            $display("Memory Operation Begin");

                            memory_unit_waiting <= 1;

                            memory_enable <= 1;
                            memory_operation <= memory_unit_operation;
                            memory_address <= memory_unit_address_value + memory_unit_address_offset;
                            memory_data_size <= memory_unit_data_size;

                            if (memory_unit_operation == 1) begin
                                memory_data_out <= memory_unit_source_value;
                            end
                        end
                    end else begin
                        if (memory_ready && !bus_asserted && !bus_to_be_asserted) begin
                            $display("Memory Operation End");

                            memory_unit_waiting <= 0;

                            bus_asserted <= 1;
                            bus_source <= station_count - 1;

                            memory_enable <= 0;

                            if (memory_unit_operation == 0) begin
                                case (memory_unit_data_size)
                                    0: begin
                                        if (memory_unit_signed) begin
                                            bus_value <= {{26{memory_data_in[7]}}, memory_data_in[6 : 0]};
                                        end else begin
                                            bus_value <= {25'b0, memory_data_in[7 : 0]};
                                        end
                                    end

                                    1: begin
                                        if (memory_unit_signed) begin
                                            bus_value <= {{16{memory_data_in[15]}}, memory_data_in[14 : 0]};
                                        end else begin
                                            bus_value <= {15'b0, memory_data_in[15 : 0]};
                                        end
                                    end

                                    2: begin
                                        bus_value <= memory_data_in;
                                    end
                                endcase
                            end
                        end
                    end
                end
            end
        end
    end
endmodule