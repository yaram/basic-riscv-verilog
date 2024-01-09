`define ARRAY(NAME, SIGNAL_SIZE, ARRAY_SIZE) [SIGNAL_SIZE - 1 : 0] NAME[0 : ARRAY_SIZE - 1]
`define FLAT_ARRAY(NAME, SIGNAL_SIZE, ARRAY_SIZE) [SIGNAL_SIZE * ARRAY_SIZE - 1 : 0] NAME``_flat

`define FLAT_EQUALS_NORMAL(ARRAY, SIGNAL_SIZE, ARRAY_SIZE) \
generate \
    for (flatten_i = 0; flatten_i < ARRAY_SIZE; flatten_i = flatten_i + 1) begin \
        assign ARRAY``_flat[flatten_i * SIGNAL_SIZE + SIGNAL_SIZE - 1 : flatten_i * SIGNAL_SIZE] = ARRAY[flatten_i]; \
    end \
endgenerate

`define NORMAL_EQUALS_FLAT(ARRAY, SIGNAL_SIZE, ARRAY_SIZE) \
generate \
    for (flatten_i = 0; flatten_i < ARRAY_SIZE; flatten_i = flatten_i + 1) begin \
        assign ARRAY[flatten_i] = ARRAY``_flat[flatten_i * SIGNAL_SIZE + SIGNAL_SIZE - 1 : flatten_i * SIGNAL_SIZE]; \
    end \
endgenerate