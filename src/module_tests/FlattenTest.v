module FlattenTest
#(
    parameter ARRAY_SIZE = 4,
    parameter SIGNAL_SIZE = 8
) (
    input `FLAT_ARRAY(signal, SIGNAL_SIZE, ARRAY_SIZE),

    output wire [SIGNAL_SIZE - 1 : 0]signal_echo_0,
    output wire [SIGNAL_SIZE - 1 : 0]signal_echo_1,
    output wire [SIGNAL_SIZE - 1 : 0]signal_echo_2,
    output wire [SIGNAL_SIZE - 1 : 0]signal_echo_3,

    input [SIGNAL_SIZE - 1 : 0]signal_2_0,
    input [SIGNAL_SIZE - 1 : 0]signal_2_1,
    input [SIGNAL_SIZE - 1 : 0]signal_2_2,
    input [SIGNAL_SIZE - 1 : 0]signal_2_3,

    output wire `FLAT_ARRAY(signal_2, SIGNAL_SIZE, ARRAY_SIZE)

);
    genvar flatten_i;

    wire `ARRAY(signal, SIGNAL_SIZE, ARRAY_SIZE);
    `NORMAL_EQUALS_FLAT(signal, SIGNAL_SIZE, ARRAY_SIZE);

    assign signal_echo_0 = signal[0];
    assign signal_echo_1 = signal[1];
    assign signal_echo_2 = signal[2];
    assign signal_echo_3 = signal[3];

    wire `ARRAY(signal_2, SIGNAL_SIZE, ARRAY_SIZE);
    `FLAT_EQUALS_NORMAL(signal_2, SIGNAL_SIZE, ARRAY_SIZE);

    assign signal_2[0] = signal_2_0;
    assign signal_2[1] = signal_2_1;
    assign signal_2[2] = signal_2_2;
    assign signal_2[3] = signal_2_3;
endmodule