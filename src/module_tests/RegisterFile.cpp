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

    top.read_index[0] = 0;
    top.read_index[1] = 0;
    top.write_enable[0] = 0;
    top.write_index[0] = 0;
    top.write_data[0] = 0;
    top.write_enable[1] = 0;
    top.write_index[1] = 0;
    top.write_data[1] = 0;

    top.reset = 1;
    step();

    top.reset = 0;
    step();

    if(top.read_data[0] != 0 || top.read_data[1] != 0) {
        test_failed("reset");
    }

    top.read_index[0] = 1;
    top.write_enable[0] = 1;
    top.write_index[0] = 1;
    top.write_data[0] = 0xCAFEBABE;
    step();

    if(top.read_data[0] != 0xCAFEBABE) {
        test_failed("write single & read single");
    }

    top.write_enable[0] = 0;
    step();

    if(top.read_data[0] != 0xCAFEBABE) {
        test_failed("write single & read single");
    }

    top.read_index[1] = 1;
    step();

    if(top.read_data[1] != 0xCAFEBABE) {
        test_failed("write single & read double overlapped");
    }

    top.read_index[1] = 0;
    top.write_enable[0] = 1;
    top.write_index[0] = 1;
    top.write_data[0] = 0xCAFEBABE;
    top.write_enable[1] = 1;
    top.write_index[1] = 0;
    top.write_data[1] = 0xFACEFEED;
    step();

    if(
        top.read_data[0] != 0xCAFEBABE ||
        top.read_data[1] != 0xFACEFEED
    ) {
        test_failed("write double & read double");
    }

    top.read_index[0] = 0;
    top.read_index[1] = 0;
    top.write_enable[0] = 1;
    top.write_index[0] = 0;
    top.write_data[0] = 0xCAFEBABE;
    top.write_enable[1] = 1;
    top.write_index[1] = 0;
    top.write_data[1] = 0xFACEFEED;
    step();

    if(
        top.read_data[0] != 0xCAFEBABE ||
        top.read_data[1] != 0xCAFEBABE
    ) {
        test_failed("write double overlapped & read double overlapped");
    }

    end();

    return 0;
}