#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VMemoryArbiter.h"
#define MODULE_NAME MemoryArbiter
#define MODULE_IS_CLOCKED
#include "shared.h"

#define SIZE 32
#define SIZE_BYTES (SIZE / 8)
#define MEMORY_WORD_ADDRESS_SIZE 30
#define ACCESSOR_COUNT 2
#define ACCESSOR_INDEX_SIZE 1

int main(int argc, char *argv[]) { 
    init();

    top.memory_ready = 0;
    top.memory_data_in = 0;
    top.accessor_memory_enable[0] = 0;
    top.accessor_memory_operation[0] = 0;
    top.accessor_memory_byte_mask[0] = 0;
    top.accessor_memory_word_address[0] = 0;
    top.accessor_memory_data_out[0] = 0;
    top.accessor_memory_enable[1] = 0;
    top.accessor_memory_operation[1] = 0;
    top.accessor_memory_byte_mask[1] = 0;
    top.accessor_memory_word_address[1] = 0;
    top.accessor_memory_data_out[1] = 0;

    top.reset = 1;
    step();

    top.reset = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("reset");
    }

    top.accessor_memory_enable[0] = 1;
    top.accessor_memory_byte_mask[0] = 0b1010;
    top.accessor_memory_word_address[0] = 0xAFEBABE;
    step();

    if(top.memory_enable != 1 || top.memory_operation != 0 || top.memory_byte_mask != 0b1010 || top.memory_word_address != 0xAFEBABE) {
        test_failed("read uncontested");
    }

    top.memory_ready = 1;
    top.memory_data_in = 0xFACEFEED;
    step();

    if(top.memory_enable != 1 || top.accessor_memory_data_in[0] != 0xFACEFEED) {
        test_failed("read uncontested");
    }

    top.accessor_memory_enable[0] = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("read uncontested");
    }

    top.memory_ready = 0;
    step();

    top.accessor_memory_enable[1] = 1;
    top.accessor_memory_operation[1] = 1;
    top.accessor_memory_byte_mask[1] = 0b0101;
    top.accessor_memory_word_address[1] = 0xAFEBABE;
    top.accessor_memory_data_out[1] = 0xFACEFEED;
    step();

    if(
        top.memory_enable != 1 ||
        top.memory_operation != 1 ||
        top.memory_byte_mask != 0b0101 ||
        top.memory_word_address != 0xAFEBABE ||
        top.memory_data_out != 0xFACEFEED
    ) {
        test_failed("write uncontested");
    }

    top.memory_ready = 1;
    step();

    if(top.memory_enable != 1) {
        test_failed("write uncontested");
    }

    top.accessor_memory_enable[1] = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("write uncontested");
    }

    top.memory_ready = 0;
    step();

    top.accessor_memory_enable[0] = 1;
    top.accessor_memory_enable[1] = 1;
    step();

    if(top.memory_enable != 1 || top.memory_operation != 0 || top.memory_byte_mask != 0b1010 || top.memory_word_address != 0xAFEBABE) {
        test_failed("read & write contested");
    }

    top.memory_ready = 1;
    top.memory_data_in = 0xFACEFEED;
    step();

    if(top.memory_enable != 1 || top.accessor_memory_data_in[0] != 0xFACEFEED) {
        test_failed("read & write contested");
    }

    top.accessor_memory_enable[0] = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("read & write contested");
    }

    top.memory_ready = 0;
    step();

    step();

    step();

    if(
        top.memory_enable != 1 ||
        top.memory_operation != 1 ||
        top.memory_byte_mask != 0b0101 ||
        top.memory_word_address != 0xAFEBABE ||
        top.memory_data_out != 0xFACEFEED
    ) {
        test_failed("read & write contested");
    }

    top.memory_ready = 1;
    step();

    if(top.memory_enable != 1) {
        test_failed("read & write contested");
    }

    top.accessor_memory_enable[1] = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("read & write contested");
    }

    end();

    return 0;
}