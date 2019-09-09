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
    reg [31 : 0]registers[0 : 30];

    reg [31 : 0]instruction;
    reg [31 : 0]instruction_program_counter;

    wire [6 : 0]opcode = instruction[6 : 0];

    wire [2 : 0]function_3 = instruction[14 : 12];
    wire [6 : 0]function_7 = instruction[31 : 25];

    wire [4 : 0]source_1_register_index = instruction[19 : 15];
    wire [4 : 0]source_2_register_index = instruction[24 : 20];
    wire [4 : 0]destination_register_index = instruction[11 : 7];

    wire [31 : 0]source_1_register = source_1_register_index == 0 ? 0 : registers[source_1_register_index - 1];
    wire [31 : 0]source_2_register = source_2_register_index == 0 ? 0 : registers[source_2_register_index - 1];

    wire [31 : 0]immediate = {{21{instruction[31]}}, instruction[30 : 20]};
    wire [31 : 0]immediate_store = {{21{instruction[31]}}, instruction[30 : 25], instruction[11 : 7]};
    wire [31 : 0]immediate_branch = {{20{instruction[31]}}, instruction[7], instruction[30 : 25], instruction[11 : 8], 1'b0};
    wire [31 : 0]immediate_upper = {instruction[31 : 12], 12'b0};
    wire [31 : 0]immediate_jump = {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0};

    reg load_stage_waiting;
    reg load_stage_loaded;
    reg load_stage_canceling;
    reg [31 : 0]load_stage_program_counter;

    reg [1 : 0]memory_stage_operation;
    reg [1 : 0]memory_stage_size;
    reg [31 : 0]memory_stage_address;
    reg [31 : 0]memory_stage_data;
    reg [4 : 0]memory_stage_register_index;
    reg memory_stage_sign_extend;
    reg memory_stage_waiting;

    task set_destination_register(
        input [31 : 0]value
    );
        if (destination_register_index != 0) begin
            registers[destination_register_index - 1] <= value;
        end
    endtask

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            $display("Reset");

            memory_enable <= 0;

            load_stage_waiting <= 0;
            load_stage_loaded <= 0;
            load_stage_canceling <= 0;
            load_stage_program_counter <= 0;

            memory_stage_operation <= 0;
            memory_stage_waiting <= 0;
        end else begin
            // Stage 0 (Instruction Load)

            if (!memory_ready && !load_stage_waiting && memory_stage_operation == 0) begin
                $display("Instruction Load Begin");

                memory_operation <= 0;
                memory_address <= load_stage_program_counter;
                memory_data_size <= 2;

                memory_enable <= 1;

                load_stage_waiting <= 1;
            end

            if (load_stage_canceling && memory_ready) begin
                $display("Instruction Load Cancel");

                load_stage_waiting <= 0;
                load_stage_canceling <= 0;

                memory_enable <= 0;
            end

            if (memory_ready && load_stage_waiting && !load_stage_loaded && !load_stage_canceling) begin
                $display("Instruction Load End");

                instruction <= memory_data_in;
                instruction_program_counter <= load_stage_program_counter;

                memory_enable <= 0;

                load_stage_waiting <= 0;
                load_stage_loaded <= 1;
                load_stage_program_counter <= load_stage_program_counter + 4;
            end

            // Stage 1 (Instruction Execution)

            if (load_stage_loaded && memory_stage_operation != 1) begin
                $display("Instruction Execute, Program Counter: %0d", instruction_program_counter);

                case (opcode[1 : 0])
                    2'b11: begin // Base instruction set
                        case (opcode[6 : 2])
                            5'b00100 : begin // OP-IMM
                                case (function_3)
                                    3'b000 : begin // ADDI
                                        $display("addi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                        set_destination_register(immediate + source_1_register);
                                    end

                                    3'b010 : begin // SLTI
                                        $display("slti x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                        if ($signed(source_1_register) < $signed(immediate)) begin
                                            set_destination_register(1);
                                        end else begin
                                            set_destination_register(0);
                                        end
                                    end

                                    3'b011 : begin // SLTIU
                                        $display("sltiu x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        if (source_1_register < immediate) begin
                                            set_destination_register(1);
                                        end else begin
                                            set_destination_register(0);
                                        end
                                    end

                                    3'b100 : begin // XORI
                                        $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        set_destination_register(source_1_register ^ immediate);
                                    end

                                    3'b110 : begin // ORI
                                        $display("ori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        set_destination_register(source_1_register | immediate);
                                    end

                                    3'b111 : begin // ANDI
                                        $display("andi x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        set_destination_register(source_1_register & immediate);
                                    end

                                    3'b001 : begin // SLLI
                                        $display("xori x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate);

                                        set_destination_register(source_1_register << immediate[4 : 0]);
                                    end

                                    3'b101 : begin
                                        if (instruction[30] === 0) begin // SRLI
                                            $display("srli x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                            set_destination_register(source_1_register >> immediate[4 : 0]);
                                        end else begin // SRAI
                                            $display("srai x%0d, x%0d, %0d", destination_register_index, source_1_register_index, immediate[4 : 0]);

                                            set_destination_register(source_1_register >>> immediate[4 : 0]);
                                        end
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase

                                load_stage_loaded <= 0;
                            end

                            5'b01100 : begin // OP
                                case (function_3)
                                    3'b000 : begin
                                        if (instruction[30] === 0) begin // ADD
                                            $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            set_destination_register(source_1_register + source_2_register);
                                        end else begin // SUB
                                            $display("add x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            set_destination_register(source_1_register - source_2_register);
                                        end
                                    end

                                    3'b010 : begin // SLT
                                        $display("slt x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        if ($signed(source_1_register) < $signed(source_2_register)) begin
                                            set_destination_register(1);
                                        end else begin
                                            set_destination_register(0);
                                        end
                                    end

                                    3'b011 : begin // SLTU
                                        $display("sltu x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        if (source_1_register < source_2_register) begin
                                            set_destination_register(1);
                                        end else begin
                                            set_destination_register(0);
                                        end
                                    end

                                    3'b100 : begin // XOR
                                        $display("xor x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        set_destination_register(source_1_register ^ source_2_register);
                                    end

                                    3'b110 : begin // OR
                                        $display("or x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        set_destination_register(source_1_register | source_2_register);
                                    end

                                    3'b111 : begin // AND
                                        $display("and x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        set_destination_register(source_1_register & source_2_register);
                                    end

                                    3'b001 : begin // SLL
                                        $display("sll x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                        set_destination_register(source_1_register >> source_2_register[4 : 0]);
                                    end

                                    3'b101 : begin
                                        if (instruction[30] === 0) begin // SRL
                                            $display("srl x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            set_destination_register(source_1_register >> source_2_register[4 : 0]);
                                        end else begin // SRA
                                            $display("sra x%0d, x%0d, x%0d", destination_register_index, source_1_register_index, source_2_register_index);

                                            set_destination_register(source_1_register >>> source_2_register[4 : 0]);
                                        end
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase

                                load_stage_loaded <= 0;
                            end

                            5'b00101 : begin // AUIPC
                                $display("auipc x%0d, %0d", destination_register_index, immediate_upper);

                                set_destination_register(instruction_program_counter + immediate_upper);

                                load_stage_loaded <= 0;
                            end

                            5'b01101 : begin // LUI
                                $display("lui x%0d, %0d", destination_register_index, immediate_upper);

                                set_destination_register(immediate_upper);

                                load_stage_loaded <= 0;
                            end

                            5'b11000 : begin // BRANCH
                                case (function_3)
                                    3'b000 : begin // BEQ
                                        if (source_1_register === source_2_register) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    3'b001 : begin // BNE
                                        if (source_1_register != source_2_register) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    3'b100 : begin // BLT
                                        if ($signed(source_1_register) < $signed(source_2_register)) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    3'b101 : begin // BGE
                                        if ($signed(source_1_register) >= $signed(source_2_register)) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    3'b110 : begin // BLTU
                                        if (source_1_register < source_2_register) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    3'b111 : begin // BGEU
                                        if (source_1_register >= source_2_register) begin
                                            load_stage_program_counter <= instruction_program_counter + immediate_branch;

                                            load_stage_canceling <= 1;
                                        end
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase

                                load_stage_loaded <= 0;
                            end

                            5'b11011 : begin // JAL
                                $display("jal x%0d, %0d", destination_register_index, $signed(immediate_jump));

                                set_destination_register(instruction_program_counter + 4);

                                load_stage_program_counter <= instruction_program_counter + immediate_jump;
                                
                                load_stage_canceling <= 1;
                                
                                load_stage_loaded <= 0;
                            end

                            5'b11001 : begin // JALR
                                $display("jalr x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                set_destination_register(instruction_program_counter + 4);

                                load_stage_program_counter = immediate + source_1_register;
                                load_stage_program_counter[0] = 0;
                                
                                load_stage_canceling <= 1;

                                load_stage_loaded <= 0;
                            end

                            5'b00000 : begin // LOAD
                                if (memory_stage_operation == 0) begin
                                    case (function_3)
                                        3'b000 : begin // LB
                                            $display("lb x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_stage_size <= 0;
                                            memory_stage_sign_extend <= 1;
                                        end

                                        3'b001 : begin // LH
                                            $display("lh x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_stage_size <= 1;
                                            memory_stage_sign_extend <= 1;
                                        end

                                        3'b010 : begin // LW
                                            $display("lw x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_stage_size <= 2;
                                            memory_stage_sign_extend <= 1;
                                        end

                                        3'b100 : begin // LBU
                                            $display("lbu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_stage_size <= 0;
                                            memory_stage_sign_extend <= 0;
                                        end

                                        3'b101 : begin // LWU
                                            $display("lhu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            memory_stage_size <= 1;
                                            memory_stage_sign_extend <= 0;
                                        end
                                    endcase

                                    memory_stage_operation <= 1;
                                    memory_stage_address <= source_1_register + immediate;
                                    memory_stage_register_index <= destination_register_index;

                                    load_stage_loaded <= 0;
                                end
                            end

                            5'b01000 : begin // STORE
                                if (memory_stage_operation == 0) begin
                                    case (function_3)
                                        3'b000 : begin // SB
                                            $display("sb x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_stage_size <= 0;
                                        end

                                        3'b001 : begin // SH
                                            $display("sh x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_stage_size <= 1;
                                        end

                                        3'b010 : begin // SW
                                            $display("sw x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_stage_size <= 2;
                                        end

                                        default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                    endcase

                                    memory_stage_operation <= 2;
                                    memory_stage_address <= source_1_register + immediate_store;
                                    memory_stage_data <= source_2_register;

                                    load_stage_loaded <= 0;
                                end
                            end

                            5'b00011 : begin // MISC-MEM
                                case (function_3)
                                    3'b000 : begin // FENCE
                                        
                                    end

                                    3'b001 : begin // FENCE.I
                                        
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase

                                load_stage_loaded <= 0;
                            end

                            5'b11100 : begin // SYSTEM
                                case (function_3)
                                    3'b000 : begin // PRIV
                                        if (instruction[20] === 0) begin // ECALL
                                            
                                        end else begin // EBREAK
                                            
                                        end
                                    end

                                    3'b001 : begin // CSRRW
                                        
                                    end

                                    3'b010 : begin // CSRRS
                                        
                                    end

                                    3'b011 : begin // CSRRC
                                        
                                    end

                                    3'b101 : begin // CSRRWI
                                        
                                    end

                                    3'b110 : begin // CSRRSI
                                        
                                    end

                                    3'b111 : begin // CSRRCI
                                        
                                    end

                                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                                endcase

                                load_stage_loaded <= 0;
                            end

                            default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                        endcase
                    end

                    default : $display("Unknown instruction %0d (%0d, %0d, %0d)", instruction, opcode, function_3, function_7);
                endcase

            end

            // Stage 2 (Memory Operation)

            if (memory_stage_operation != 0 && !memory_stage_waiting && !memory_ready && !load_stage_waiting) begin
                $display("Memory Operation Begin");

                case (memory_stage_operation)
                    1: begin
                        memory_operation <= 0;
                    end

                    2: begin
                        memory_operation <= 1;

                        memory_data_out <= memory_stage_data;
                    end
                endcase

                memory_address <= memory_stage_address;
                memory_data_size <= memory_stage_size;
                memory_enable <= 1;

                memory_stage_waiting <= 1;
            end

            if (memory_stage_waiting && memory_ready) begin
                $display("Memory Operation End");

                if (memory_stage_operation == 1 && memory_stage_register_index != 0) begin
                    registers[memory_stage_register_index - 1] <= memory_data_in;
                end

                memory_stage_operation <= 0;
                memory_stage_waiting <= 0;

                memory_enable <= 0;
            end
        end
    end
endmodule