module CPU(
    input wire clock,
    output reg [31 : 0]memory_address,
    input wire [31 : 0]memory_data_in,
    output reg [31 : 0]memory_data_out,
    output reg [1 : 0]memory_data_size,
    output reg memory_enable = 0,
    output reg memory_operation,
    input wire memory_ready
);
    reg [31 : 0]registers[0 : 31];

    integer i;
    initial begin
        for(i = 0; i < 32; i = i + 1) begin
            registers[i] = 0;
        end
    end

    reg [31 : 0]program_counter = 0;

    reg [31 : 0]instruction;

    wire [6 : 0]opcode = instruction[6 : 0];

    wire [2 : 0]function_3 = instruction[14 : 12];
    wire [6 : 0]function_7 = instruction[31 : 25];

    wire [4 : 0]source_1_register_index = instruction[19 : 15];
    wire [4 : 0]source_2_register_index = instruction[24 : 20];
    wire [4 : 0]destination_register_index = instruction[11 : 7];

    wire [31 : 0]source_1_register = registers[source_1_register_index];
    wire [31 : 0]source_2_register = registers[source_2_register_index];

    wire [31 : 0]immediate = {{21{instruction[31]}}, instruction[30 : 20]};
    wire [31 : 0]immediate_store = {{21{instruction[31]}}, instruction[30 : 25], instruction[11 : 7]};
    wire [31 : 0]immediate_branch = {{20{instruction[31]}}, instruction[7], instruction[30 : 25], instruction[11 : 8], 1'b0};
    wire [31 : 0]immediate_upper = {instruction[31 : 12], 12'b0};
    wire [31 : 0]immediate_jump = {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0};

    integer stage = 0;

    task set_destination_register(
        input [31 : 0]value
    );
        if (destination_register_index != 0) begin
            registers[destination_register_index] = value;
        end
    endtask

    always @(posedge clock) begin
        $display("Stage: %d", stage);

        case (stage)
            0: begin
                if (!memory_ready) begin
                    memory_operation = 0;
                    memory_address = program_counter;
                    memory_data_size = 2;

                    memory_enable = 1;

                    stage = 1;
                end
            end

            1: begin
                if (memory_ready) begin
                    instruction = memory_data_in;

                    memory_enable = 0;

                    stage = 2;
                end
            end

            2: begin
                if (!memory_ready) begin
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

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    program_counter = program_counter + 4;
                                    stage = 0;
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

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    program_counter = program_counter + 4;
                                    stage = 0;
                                end

                                5'b00101 : begin // AUIPC
                                    $display("auipc x%0d, %0d", destination_register_index, immediate_upper);

                                    program_counter = program_counter + immediate_upper;

                                    set_destination_register(program_counter);

                                    stage = 0;
                                end

                                5'b01101 : begin // LUI
                                    $display("lui x%0d, %0d", destination_register_index, immediate_upper);

                                    set_destination_register(immediate_upper);

                                    program_counter = program_counter + 4;
                                    stage = 0;
                                end

                                5'b11000 : begin // BRANCH
                                    case (function_3)
                                        3'b000 : begin // BEQ
                                            if (source_1_register === source_2_register) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b001 : begin // BNE
                                            if (source_1_register != source_2_register) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b100 : begin // BLT
                                            if ($signed(source_1_register) < $signed(source_2_register)) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b101 : begin // BGE
                                            if ($signed(source_1_register) >= $signed(source_2_register)) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b110 : begin // BLTU
                                            if (source_1_register < source_2_register) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b111 : begin // BGEU
                                            if (source_1_register >= source_2_register) begin
                                                program_counter = program_counter + immediate_branch;
                                            end else begin
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    stage = 0;
                                end

                                5'b11001 : begin // JAL
                                    $display("jal x%0d, %0d", destination_register_index, $signed(immediate_jump));

                                    set_destination_register(program_counter + 4);

                                    program_counter = program_counter + immediate_jump;
                                    stage = 0;
                                end

                                5'b11011 : begin // JALR
                                    $display("jalr x%0d, x%0d, %0d", destination_register_index, source_1_register_index, $signed(immediate));

                                    set_destination_register(program_counter + 4);

                                    program_counter = program_counter + immediate + source_1_register;
                                    program_counter[0] = 0;
                                    stage = 0;
                                end

                                5'b00000 : begin // LOAD
                                    memory_operation = 0;
                                    memory_address = source_1_register + immediate;

                                    memory_enable = 1;

                                    stage = 3;
                                end

                                5'b01000 : begin // STORE
                                    memory_operation = 1;
                                    memory_address = source_1_register + immediate_store;

                                    case (function_3)
                                        3'b000 : begin // SB
                                            $display("sb x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_data_size = 0;

                                            memory_data_out[7 : 0] = source_2_register[7 : 0];
                                        end

                                        3'b001 : begin // SH
                                            $display("sh x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_data_size = 1;

                                            memory_data_out[15 : 0] = source_2_register[15 : 0];
                                        end

                                        3'b010 : begin // SW
                                            $display("sw x%0d, %0d(x%0d)", source_2_register_index, $signed(immediate_store), source_1_register_index);

                                            memory_data_size = 2;

                                            memory_data_out = source_2_register;
                                        end

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    memory_enable = 1;
                                    
                                    stage = 3;
                                end

                                5'b00011 : begin // MISC-MEM
                                    case (function_3)
                                        3'b000 : begin // FENCE
                                            
                                        end

                                        3'b001 : begin // FENCE.I
                                            
                                        end

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    program_counter = program_counter + 4;
                                    stage = 0;
                                end

                                5'b11100 : begin // SYSTEM
                                    case (function_3)
                                        3'b000 : begin // PRIV
                                            if (instruction[20] === 0) begin // ECALL
                                                
                                            end else begin // EBREAK
                                                program_counter = program_counter + 4;
                                            end
                                        end

                                        3'b001 : begin // CSRRW
                                            program_counter = program_counter + 4;
                                        end

                                        3'b010 : begin // CSRRS
                                            program_counter = program_counter + 4;
                                        end

                                        3'b011 : begin // CSRRC
                                            program_counter = program_counter + 4;
                                        end

                                        3'b101 : begin // CSRRWI
                                            program_counter = program_counter + 4;
                                        end

                                        3'b110 : begin // CSRRSI
                                            program_counter = program_counter + 4;
                                        end

                                        3'b111 : begin // CSRRCI
                                            program_counter = program_counter + 4;
                                        end

                                        default : $display("Unknown instruction %0d", instruction);
                                    endcase

                                    stage = 3;
                                end

                                default : $display("Unknown instruction %0d", instruction);
                            endcase
                        end

                        default : $display("Unknown instruction %0d", instruction);
                    endcase
                end
            end

            3: begin
                if (memory_ready) begin
                    case (opcode[1 : 0])
                        2'b11: begin // Base instruction set
                            case (opcode[6 : 2])
                                5'b00000 : begin // LOAD
                                    case (function_3)
                                        3'b000 : begin // LB
                                            $display("lb x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            set_destination_register({{25{memory_data_in[7]}}, memory_data_in[6 : 0]});
                                        end

                                        3'b001 : begin // LH
                                            $display("lh x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            set_destination_register({{17{memory_data_in[15]}}, memory_data_in[14 : 0]});
                                        end

                                        3'b010 : begin // LW
                                            $display("lw x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            set_destination_register(memory_data_in);
                                        end

                                        3'b100 : begin // LBU
                                            $display("lbu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            set_destination_register({24'b0, memory_data_in[7 : 0]});
                                        end

                                        3'b101 : begin // LWU
                                            $display("lhu x%0d, %0d(x%0d)", destination_register_index, $signed(immediate), source_1_register_index);

                                            set_destination_register({16'b0, memory_data_in[15 : 0]});
                                        end
                                    endcase
                                end
                            endcase
                        end
                    endcase

                    memory_enable = 0;

                    program_counter = program_counter + 4;

                    stage = 0;
                end
            end
        endcase
    end
endmodule