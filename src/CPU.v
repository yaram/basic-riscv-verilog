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
    wire [31 : 0]immediate_upper = {instruction[31 : 12], 12'b0};
    wire [31 : 0]immediate_jump = {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0};

    parameter alu_count = 4;
    parameter alu_index_size = 2;

    reg register_busy_states[0 : 30];
    reg [alu_index_size : 0]register_alu_indices[0 : 30];
    reg [31 : 0]register_values[0 : 30];

    reg [4 : 0]alu_operations[0 : alu_count - 1];
    reg alu_occupied_states[0 : alu_count - 1];
    reg [alu_index_size - 1 : 0]alu_source_1_indices[0 : alu_count - 1];
    reg [alu_index_size - 1 : 0]alu_source_2_indices[0 : alu_count - 1];
    reg alu_source_1_loaded_states[0 : alu_count - 1];
    reg alu_source_2_loaded_states[0 : alu_count - 1];
    reg [31 : 0]alu_source_1_values[0 : alu_count - 1];
    reg [31 : 0]alu_source_2_values[0 : alu_count - 1];

    reg bus_asserted;
    reg [alu_index_size - 1 : 0]bus_source;
    reg [31 : 0]bus_value;

    integer i;

    reg unoccupied_alu_found;
    reg [alu_index_size - 1 : 0]unoccupied_alu_index;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            $display("Reset");

            memory_enable <= 0;

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

            bus_asserted <= 0;
        end else begin
            // Instruction Load

            if (!memory_ready && !instruction_load_waiting && !instruction_load_canceling) begin
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
                                unoccupied_alu_found = 0;

                                for (i = 0; i < alu_count; i = i + 1) begin
                                    if (!alu_occupied_states[i] && !unoccupied_alu_found) begin
                                        unoccupied_alu_found = 1;
                                        unoccupied_alu_index = i;
                                    end
                                end

                                instruction_load_loaded <= 0;
                                alu_occupied_states[unoccupied_alu_index] <= 1;

                                if (source_1_register_index == 0) begin
                                    alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                    alu_source_1_values[unoccupied_alu_index] <= 0;
                                end else begin
                                    if (register_busy_states[source_1_register_index - 1]) begin
                                        if (bus_asserted && bus_source == register_alu_indices[source_1_register_index - 1]) begin
                                            alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                            alu_source_1_values[unoccupied_alu_index] <= bus_value;
                                        end else begin
                                            alu_source_1_loaded_states[unoccupied_alu_index] <= 0;
                                            alu_source_1_indices[unoccupied_alu_index] <= register_alu_indices[source_1_register_index - 1];
                                        end
                                    end else begin
                                        alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                        alu_source_1_values[unoccupied_alu_index] <= register_values[source_1_register_index - 1];
                                    end
                                end

                                alu_source_2_loaded_states[unoccupied_alu_index] <= 1;
                                alu_source_2_values[unoccupied_alu_index] <= immediate;

                                if (destination_register_index != 0) begin
                                    register_busy_states[destination_register_index - 1] <= 1;
                                    register_alu_indices[destination_register_index - 1] <= unoccupied_alu_index;
                                end

                                case (function_3)
                                    3'b000 : begin // ADDI
                                        $display("addi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                        alu_operations[unoccupied_alu_index] <= 0;
                                    end

                                    3'b010 : begin // SLTI
                                        $display("slti x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                        alu_operations[unoccupied_alu_index] <= 9;
                                    end

                                    3'b011 : begin // SLTIU
                                        $display("sltiu x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        alu_operations[unoccupied_alu_index] <= 8;
                                    end

                                    3'b100 : begin // XORI
                                        $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        alu_operations[unoccupied_alu_index] <= 4;
                                    end

                                    3'b110 : begin // ORI
                                        $display("ori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        alu_operations[unoccupied_alu_index] <= 2;
                                    end

                                    3'b111 : begin // ANDI
                                        $display("andi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        alu_operations[unoccupied_alu_index] <= 3;
                                    end

                                    3'b001 : begin // SLLI
                                        $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        alu_operations[unoccupied_alu_index] <= 5;
                                    end

                                    3'b101 : begin
                                        if (instruction[30] == 0) begin // SRLI
                                            $display("srli x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                            alu_operations[unoccupied_alu_index] <= 6;
                                        end else begin // SRAI
                                            $display("srai x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                            alu_operations[unoccupied_alu_index] <= 7;
                                        end
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase
                            end

                            5'b01100 : begin // OP
                                unoccupied_alu_found = 0;

                                for (i = 0; i < alu_count; i = i + 1) begin
                                    if (!alu_occupied_states[i] && !unoccupied_alu_found) begin
                                        unoccupied_alu_found = 1;
                                        unoccupied_alu_index = i;
                                    end
                                end

                                instruction_load_loaded <= 0;
                                alu_occupied_states[unoccupied_alu_index] <= 1;

                                if (source_1_register_index == 0) begin
                                    alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                    alu_source_1_values[unoccupied_alu_index] <= 0;
                                end else begin
                                    if (register_busy_states[source_1_register_index - 1]) begin
                                        if (bus_asserted && bus_source == register_alu_indices[source_1_register_index - 1]) begin
                                            alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                            alu_source_1_values[unoccupied_alu_index] <= bus_value;
                                        end else begin
                                            alu_source_1_loaded_states[unoccupied_alu_index] <= 0;
                                            alu_source_1_indices[unoccupied_alu_index] <= register_alu_indices[source_1_register_index - 1];
                                        end
                                    end else begin
                                        alu_source_1_loaded_states[unoccupied_alu_index] <= 1;
                                        alu_source_1_values[unoccupied_alu_index] <= register_values[source_1_register_index - 1];
                                    end
                                end

                                if (source_2_register_index == 0) begin
                                    alu_source_2_loaded_states[unoccupied_alu_index] <= 1;
                                    alu_source_2_values[unoccupied_alu_index] <= 0;
                                end else begin
                                    if (register_busy_states[source_2_register_index - 1]) begin
                                        if (bus_asserted && bus_source == register_alu_indices[source_2_register_index - 1]) begin
                                            alu_source_2_loaded_states[unoccupied_alu_index] <= 1;
                                            alu_source_2_values[unoccupied_alu_index] <= bus_value;
                                        end else begin
                                            alu_source_2_loaded_states[unoccupied_alu_index] <= 0;
                                            alu_source_2_indices[unoccupied_alu_index] <= register_alu_indices[source_2_register_index - 1];
                                        end
                                    end else begin
                                        alu_source_2_loaded_states[unoccupied_alu_index] <= 1;
                                        alu_source_2_values[unoccupied_alu_index] <= register_values[source_2_register_index - 1];
                                    end
                                end

                                if (destination_register_index != 0) begin
                                    register_busy_states[destination_register_index - 1] <= 1;
                                    register_alu_indices[destination_register_index - 1] <= unoccupied_alu_index;
                                end

                                case (function_3)
                                    3'b000 : begin
                                        if (instruction[30] == 0) begin // ADD
                                            $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            alu_operations[unoccupied_alu_index] <= 0;
                                        end else begin // SUB
                                            $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            alu_operations[unoccupied_alu_index] <= 1;
                                        end
                                    end

                                    3'b010 : begin // SLT
                                        $display("slt x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 9;
                                    end

                                    3'b011 : begin // SLTU
                                        $display("sltu x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 8;
                                    end

                                    3'b100 : begin // XOR
                                        $display("xor x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 4;
                                    end

                                    3'b110 : begin // OR
                                        $display("or x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 2;
                                    end

                                    3'b111 : begin // AND
                                        $display("and x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 3;
                                    end

                                    3'b001 : begin // SLL
                                        $display("sll x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        alu_operations[unoccupied_alu_index] <= 5;
                                    end

                                    3'b101 : begin
                                        if (instruction[30] == 0) begin // SRL
                                            $display("srl x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            alu_operations[unoccupied_alu_index] <= 6;
                                        end else begin // SRA
                                            $display("sra x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            alu_operations[unoccupied_alu_index] <= 7;
                                        end
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase
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

                                        default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
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
                                        instruction_load_program_counter = immediate;
                                    end else begin
                                        instruction_load_program_counter = immediate + register_values[source_1_register_index - 1];
                                    end

                                    instruction_load_program_counter[0] = 0;

                                    instruction_load_canceling <= 1;

                                    instruction_load_loaded <= 0;
                                end
                            end

                            default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                        endcase
                    end

                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                endcase
            end

            // Instruction Execution (ALUs)

            for (i = 0; i < 31; i = i + 1) begin
                if (register_busy_states[i] && bus_asserted && bus_source == register_alu_indices[i]) begin
                    register_busy_states[i] <= 0;
                    register_values[i] <= bus_value;
                end
            end

            for (i = 0; i < alu_count; i = i + 1) begin
                if (alu_occupied_states[i]) begin
                    if (!alu_source_1_loaded_states[i] && bus_source == alu_source_1_indices[i]) begin
                        alu_source_1_loaded_states[i] <= 1;
                        alu_source_1_values[i] <= bus_value;
                    end

                    if (!alu_source_2_loaded_states[i] && bus_source == alu_source_2_indices[i]) begin
                        alu_source_2_loaded_states[i] <= 1;
                        alu_source_2_values[i] <= bus_value;
                    end

                    if (bus_asserted && bus_source == i) begin
                        bus_asserted <= 0;
                        alu_occupied_states[i] <= 0;
                    end

                    if (alu_source_1_loaded_states[i] && alu_source_2_loaded_states[i] && !bus_asserted) begin
                        bus_source = i;
                        bus_asserted = 1;

                        case (alu_operations[i])
                            0 : begin
                                bus_value = alu_source_1_values[i] + alu_source_2_values[i];
                            end

                            1 : begin
                                bus_value = alu_source_1_values[i] - alu_source_2_values[i];
                            end

                            2 : begin
                                bus_value = alu_source_1_values[i] | alu_source_2_values[i];
                            end

                            3 : begin
                                bus_value = alu_source_1_values[i] & alu_source_2_values[i];
                            end

                            4 : begin
                                bus_value = alu_source_1_values[i] ^ alu_source_2_values[i];
                            end

                            5 : begin
                                bus_value = alu_source_1_values[i] << alu_source_2_values[i];
                            end

                            6 : begin
                                bus_value = alu_source_1_values[i] >> alu_source_2_values[i];
                            end

                            7 : begin
                                bus_value = alu_source_1_values[i] >>> alu_source_2_values[i];
                            end

                            8 : begin
                                bus_value = alu_source_1_values[i] < alu_source_2_values[i];
                            end

                            9 : begin
                                bus_value = $signed(alu_source_1_values[i]) < $signed(alu_source_2_values[i]);
                            end
                        endcase
                    end
                end
            end
        end
    end
endmodule