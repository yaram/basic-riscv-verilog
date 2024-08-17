`default_nettype none

module InstructionDecoder (
    input [31 : 0]instruction,

    output logic valid_instruction,

    output [4 : 0]source_1_register_index,
    output logic source_2_is_immediate,
    output [4 : 0]source_2_register_index,
    output logic [31 : 0]source_2_immediate_value,
    output [4 : 0]destination_register_index,

    output logic integer_unit,
    output logic [3 : 0]integer_unit_operation,

    output logic multiplier,
    output logic [1 : 0]multiplier_operation,
    output logic multiplier_source_1_signed,
    output logic multiplier_source_2_signed,
    output logic multiplier_upper_result,

    output logic load_immediate,
    output logic load_immediate_add_instruction_counter,
    output [31 : 0]load_immediate_value,

    output logic branch,
    output logic [2 : 0]branch_condition,
    output [31 : 0]branch_immediate,

    output logic jump_and_link,
    output logic jump_and_link_relative,
    output [31 : 0]jump_and_link_immediate,
    output [31 : 0]jump_and_link_relative_immediate,

    output logic memory_unit,
    output logic memory_unit_operation,
    output logic [1 : 0]memory_unit_data_size,
    output logic memory_unit_signed,
    output logic [31 : 0]memory_unit_address_offset_immediate,

    output logic fence
);
    logic [6 : 0]opcode = instruction[6 : 0];

    logic [2 : 0]function_3 = instruction[14 : 12];
    logic [6 : 0]function_7 = instruction[31 : 25];

    assign source_1_register_index = instruction[19 : 15];
    assign source_2_register_index = instruction[24 : 20];
    assign destination_register_index = instruction[11 : 7];

    logic [31 : 0]immediate = {{21{instruction[31]}}, instruction[30 : 20]};
    logic [31 : 0]immediate_store = {{21{instruction[31]}}, instruction[30 : 25], instruction[11 : 7]};
    logic [31 : 0]immediate_branch = {{20{instruction[31]}}, instruction[7], instruction[30 : 25], instruction[11 : 8], 1'b0};
    logic [19 : 0]immediate_upper = instruction[31 : 12];
    logic [31 : 0]immediate_jump = {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0};

    assign load_immediate_value = {immediate_upper, 12'b0};

    assign branch_immediate = immediate_branch;

    assign jump_and_link_immediate = immediate_jump;
    assign jump_and_link_relative_immediate = immediate;

    always_comb begin
        valid_instruction = 1;

        source_2_is_immediate = 0;
        source_2_immediate_value = 0;

        integer_unit = 0;
        integer_unit_operation = 0;

        multiplier = 0;
        multiplier_operation = 0;
        multiplier_source_1_signed = 0;
        multiplier_source_2_signed = 0;
        multiplier_upper_result = 0;

        load_immediate = 0;
        load_immediate_add_instruction_counter = 0;

        branch = 0;
        branch_condition = 0;

        jump_and_link = 0;
        jump_and_link_relative = 0;

        memory_unit = 0;
        memory_unit_operation = 0;
        memory_unit_data_size = 0;
        memory_unit_signed = 0;

        memory_unit_address_offset_immediate = 0;

        fence = 0;

        case (opcode[1 : 0])
            2'b11: begin // Base instruction set
                case (opcode[6 : 2])
                    5'b00100 : begin // OP-IMM
                        integer_unit = 1;
                        source_2_is_immediate = 1;
                        source_2_immediate_value = immediate;

                        case (function_3)
                            3'b000 : begin // ADDI
                                integer_unit_operation = 0;
                            end

                            3'b010 : begin // SLTI
                                integer_unit_operation = 9;
                            end

                            3'b011 : begin // SLTIU
                                integer_unit_operation = 8;
                            end

                            3'b100 : begin // XORI
                                integer_unit_operation = 4;
                            end

                            3'b110 : begin // ORI
                                integer_unit_operation = 2;
                            end

                            3'b111 : begin // ANDI
                                integer_unit_operation = 3;
                            end

                            3'b001 : begin // SLLI
                                if (function_7 == 7'b0000000) begin
                                    integer_unit_operation = 5;
                                end else begin
                                    valid_instruction = 0;
                                end
                            end

                            3'b101 : begin
                                case (function_7)
                                    7'b0000000: begin // SRLI
                                        integer_unit_operation = 6;
                                    end

                                    7'b0100000: begin // SRAI
                                        integer_unit_operation = 7;
                                    end

                                    default: begin
                                        valid_instruction = 0;
                                    end
                                endcase
                            end

                            default : begin
                                valid_instruction = 0;
                            end
                        endcase
                    end

                    5'b01100 : begin // OP
                        case (function_7)
                            7'b0000001 : begin // MULDIV
                                multiplier = 1;

                                case (function_3)
                                    3'b000 : begin // MUL
                                        multiplier_operation = 0;
                                        multiplier_source_1_signed = 0;
                                        multiplier_source_2_signed = 0;
                                        multiplier_upper_result = 0;
                                    end

                                    3'b001 : begin // MULH
                                        multiplier_operation = 0;
                                        multiplier_source_1_signed = 1;
                                        multiplier_source_2_signed = 1;
                                        multiplier_upper_result = 1;
                                    end

                                    3'b010 : begin // MULHSU
                                        multiplier_operation = 0;
                                        multiplier_source_1_signed = 1;
                                        multiplier_source_2_signed = 0;
                                        multiplier_upper_result = 1;
                                    end

                                    3'b011 : begin // MULHU
                                        multiplier_operation = 0;
                                        multiplier_source_1_signed = 0;
                                        multiplier_source_2_signed = 0;
                                        multiplier_upper_result = 1;
                                    end

                                    3'b100 : begin // DIV
                                        multiplier_operation = 1;
                                        multiplier_source_1_signed = 1;
                                        multiplier_source_2_signed = 1;
                                    end

                                    3'b101 : begin // DIVU
                                        multiplier_operation = 1;
                                        multiplier_source_1_signed = 0;
                                        multiplier_source_2_signed = 0;
                                    end

                                    3'b110 : begin // REM
                                        multiplier_operation = 2;
                                        multiplier_source_1_signed = 1;
                                        multiplier_source_2_signed = 1;
                                    end

                                    3'b111 : begin // REMU
                                        multiplier_operation = 2;
                                        multiplier_source_1_signed = 0;
                                        multiplier_source_2_signed = 0;
                                    end

                                    default : begin
                                        valid_instruction = 0;
                                    end
                                endcase
                            end

                            default : begin
                                integer_unit = 1;

                                case (function_7)
                                    7'b0000000: begin
                                        case (function_3)
                                            3'b000: begin // ADD
                                                integer_unit_operation = 0;
                                            end

                                            3'b001 : begin // SLL
                                                integer_unit_operation = 5;
                                            end

                                            3'b010 : begin // SLT
                                                integer_unit_operation = 9;
                                            end

                                            3'b011 : begin // SLTU
                                                integer_unit_operation = 8;
                                            end

                                            3'b100 : begin // XOR
                                                integer_unit_operation = 4;
                                            end

                                            3'b101 : begin // SRL
                                                integer_unit_operation = 6;
                                            end

                                            3'b110 : begin // OR
                                                integer_unit_operation = 2;
                                            end

                                            3'b111 : begin // AND
                                                integer_unit_operation = 3;
                                            end

                                            default: begin
                                                valid_instruction = 0;
                                            end
                                        endcase
                                    end

                                    7'b0100000: begin
                                        case (function_3)
                                            3'b000: begin // SUB
                                                integer_unit_operation = 1;
                                            end

                                            3'b101 : begin // SRA
                                                integer_unit_operation = 7;
                                            end

                                            default: begin
                                                valid_instruction = 0;
                                            end
                                        endcase
                                    end

                                    default: begin
                                        valid_instruction = 0;
                                    end
                                endcase
                            end
                        endcase
                    end

                    5'b00101 : begin // AUIPC
                        load_immediate = 1;
                        load_immediate_add_instruction_counter = 1;
                    end

                    5'b01101 : begin // LUI
                        load_immediate = 1;
                    end

                    5'b11000 : begin // BRANCH
                        branch = 1;

                        case (function_3)
                            3'b000 : begin // BEQ
                                branch_condition = 0;
                            end

                            3'b001 : begin // BNE
                                branch_condition = 1;
                            end

                            3'b100 : begin // BLT
                                branch_condition = 2;
                            end

                            3'b101 : begin // BGE
                                branch_condition = 3;
                            end

                            3'b110 : begin // BLTU
                                branch_condition = 4;
                            end

                            3'b111 : begin // BGEU
                                branch_condition = 5;
                            end

                            default : begin
                                valid_instruction = 0;
                            end
                        endcase
                    end

                    5'b11011 : begin // JAL
                        jump_and_link = 1;
                    end

                    5'b11001 : begin // JALR
                        jump_and_link = 1;
                        jump_and_link_relative = 1;
                    end

                    5'b00000 : begin // LOAD
                        memory_unit = 1;
                        memory_unit_operation = 0;
                        memory_unit_address_offset_immediate = immediate;

                        case (function_3)
                            3'b000 : begin // LB
                                memory_unit_data_size = 0;
                                memory_unit_signed = 1;
                            end

                            3'b001 : begin // LH
                                memory_unit_data_size = 1;
                                memory_unit_signed = 1;
                            end

                            3'b010 : begin // LW
                                memory_unit_data_size = 2;
                                memory_unit_signed = 1;
                            end

                            3'b100 : begin // LBU
                                memory_unit_data_size = 0;
                                memory_unit_signed = 0;
                            end

                            3'b101 : begin // LHU
                                memory_unit_data_size = 1;
                                memory_unit_signed = 0;
                            end

                            default : begin
                                valid_instruction = 0;
                            end
                        endcase
                    end

                    5'b01000 : begin // STORE
                        memory_unit = 1;
                        memory_unit_operation = 1;
                        memory_unit_address_offset_immediate = immediate_store;

                        case (function_3)
                            3'b000 : begin // SB
                                memory_unit_data_size = 0;
                            end

                            3'b001 : begin // SH
                                memory_unit_data_size = 1;
                            end

                            3'b010 : begin // SW
                                memory_unit_data_size = 2;
                            end

                            default : begin
                                valid_instruction = 0;
                            end
                        endcase
                    end

                    5'b00011 : begin // MISC-MEM
                        fence = 1;

                        case (function_3)
                            3'b000 : begin // FENCE
                            end

                            3'b001 : begin // FENCE.I
                            end

                            default : begin
                                valid_instruction = 0;
                            end
                        endcase
                    end

                    default : begin
                        valid_instruction = 0;
                    end
                endcase
            end

            default : begin
                valid_instruction = 0;
            end
        endcase
    end
endmodule