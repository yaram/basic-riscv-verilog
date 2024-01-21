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
    top.accessor_memory_enable_flat = 0;
    top.accessor_memory_operation_flat = 0;
    top.accessor_memory_byte_mask_flat = 0;
    top.accessor_memory_word_address_flat = 0;
    top.accessor_memory_data_out_flat = 0;

    top.reset = 1;
    step();

    top.reset = 0;
    step();

    if(top.memory_enable != 0) {
        test_failed("reset");
    }

    set_bit(&top.accessor_memory_enable_flat, 0);
    set_sub_bits(&top.accessor_memory_byte_mask_flat, 0 * SIZE_BYTES, SIZE_BYTES, 0b1010);
    set_sub_bits(&top.accessor_memory_word_address_flat, 0 * MEMORY_WORD_ADDRESS_SIZE, MEMORY_WORD_ADDRESS_SIZE, 0xAFEBABE);
    step();

    if(top.memory_enable != 1 || top.memory_operation != 0 || top.memory_byte_mask != 0b1010 || top.memory_word_address != 0xAFEBABE) {
        test_failed("read uncontested");
    }

    top.memory_ready = 1;
    top.memory_data_in = 0xFACEFEED;
    step();

    if(top.memory_enable != 1 || get_sub_bits(top.accessor_memory_data_in_flat, 0 * SIZE, SIZE) != 0xFACEFEED) {
        test_failed("read uncontested");
    }

    unset_bit(&top.accessor_memory_enable_flat, 0);
    step();

    if(top.memory_enable != 0) {
        test_failed("read uncontested");
    }

    top.memory_ready = 0;
    step();

    set_bit(&top.accessor_memory_enable_flat, 1);
    set_bit(&top.accessor_memory_operation_flat, 1);
    set_sub_bits(&top.accessor_memory_byte_mask_flat, 1 * SIZE_BYTES, SIZE_BYTES, 0b0101);
    set_sub_bits(&top.accessor_memory_word_address_flat, 1 * MEMORY_WORD_ADDRESS_SIZE, MEMORY_WORD_ADDRESS_SIZE, 0xAFEBABE);
    set_sub_bits(&top.accessor_memory_data_out_flat, 1 * SIZE, SIZE, 0xFACEFEED);
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

    unset_bit(&top.accessor_memory_enable_flat, 1);
    step();

    if(top.memory_enable != 0) {
        test_failed("write uncontested");
    }

    top.memory_ready = 0;
    step();

    set_bit(&top.accessor_memory_enable_flat, 0);
    set_bit(&top.accessor_memory_enable_flat, 1);
    step();

    if(top.memory_enable != 1 || top.memory_operation != 0 || top.memory_byte_mask != 0b1010 || top.memory_word_address != 0xAFEBABE) {
        test_failed("read & write contested");
    }

    top.memory_ready = 1;
    top.memory_data_in = 0xFACEFEED;
    step();

    if(top.memory_enable != 1 || get_sub_bits(top.accessor_memory_data_in_flat, 0 * SIZE, SIZE) != 0xFACEFEED) {
        test_failed("read & write contested");
    }

    unset_bit(&top.accessor_memory_enable_flat, 0);
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

    unset_bit(&top.accessor_memory_enable_flat, 1);
    step();

    if(top.memory_enable != 0) {
        test_failed("read & write contested");
    }

    end();

    return 0;
}