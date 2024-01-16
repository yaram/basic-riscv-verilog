#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VRegisterFile.h"
#define MODULE_NAME RegisterFile
#define MODULE_IS_CLOCKED
#include "shared.h"

#define SIZE 32
#define REGISTER_INDEX_SIZE 2
#define READ_COUNT 2
#define WRITE_COUNT 2

int main(int argc, char *argv[]) { 
    init();

    top.read_index_flat = 0;
    top.write_enable_flat = 0;
    top.write_index_flat = 0;
    top.write_data_flat = 0;

    top.reset = 1;
    step();

    top.reset = 0;
    step();

    if(top.read_data_flat != 0) {
        test_failed("reset");
    }

    set_sub_bits(&top.read_index_flat, 0 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 1);
    set_bit(&top.write_enable_flat, 0);
    set_sub_bits(&top.write_index_flat, 0 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 1);
    set_sub_bits(&top.write_data_flat, 0 * SIZE, SIZE, 0xCAFEBABE);
    step();

    if(get_sub_bits(top.read_data_flat, 0 * SIZE, SIZE) != 0xCAFEBABE) {
        test_failed("write single & read single");
    }

    unset_bit(&top.write_enable_flat, 0);
    step();

    if(get_sub_bits(top.read_data_flat, 0 * SIZE, SIZE) != 0xCAFEBABE) {
        test_failed("write single & read single");
    }

    set_sub_bits(&top.read_index_flat, 1 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 1);
    step();

    if(get_sub_bits(top.read_data_flat, 1 * SIZE, SIZE) != 0xCAFEBABE) {
        test_failed("write single & read double overlapped");
    }

    set_sub_bits(&top.read_index_flat, 1 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_bit(&top.write_enable_flat, 0);
    set_sub_bits(&top.write_index_flat, 0 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 1);
    set_sub_bits(&top.write_data_flat, 0 * SIZE, SIZE, 0xCAFEBABE);
    set_bit(&top.write_enable_flat, 1);
    set_sub_bits(&top.write_index_flat, 1 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_sub_bits(&top.write_data_flat, 1 * SIZE, SIZE, 0xFACEFEED);
    step();

    if(
        get_sub_bits(top.read_data_flat, 0 * SIZE, SIZE) != 0xCAFEBABE ||
        get_sub_bits(top.read_data_flat, 1 * SIZE, SIZE) != 0xFACEFEED
    ) {
        test_failed("write double & read double");
    }

    set_sub_bits(&top.read_index_flat, 0 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_sub_bits(&top.read_index_flat, 1 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_bit(&top.write_enable_flat, 0);
    set_sub_bits(&top.write_index_flat, 0 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_sub_bits(&top.write_data_flat, 0 * SIZE, SIZE, 0xCAFEBABE);
    set_bit(&top.write_enable_flat, 1);
    set_sub_bits(&top.write_index_flat, 1 * REGISTER_INDEX_SIZE, REGISTER_INDEX_SIZE, 0);
    set_sub_bits(&top.write_data_flat, 1 * SIZE, SIZE, 0xFACEFEED);
    step();

    if(
        get_sub_bits(top.read_data_flat, 0 * SIZE, SIZE) != 0xCAFEBABE ||
        get_sub_bits(top.read_data_flat, 1 * SIZE, SIZE) != 0xCAFEBABE
    ) {
        test_failed("write double overlapped & read double overlapped");
    }

    end();

    return 0;
}