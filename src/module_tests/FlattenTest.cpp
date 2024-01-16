#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VFlattenTest.h"
#define MODULE_NAME FlattenTest
#include "shared.h"

int main(int argc, char *argv[]) { 
    init();

    top.signal_flat = 0xCAFEBABE;

    do_eval();

    if(top.signal_echo_0 != 0xBE || top.signal_echo_1 != 0xBA || top.signal_echo_2 != 0xFE || top.signal_echo_3 != 0xCA) {
        test_failed("NORMAL_EQUALS_FLAT");
    }

    top.signal_2_0 = 0xED;
    top.signal_2_1 = 0xFE;
    top.signal_2_2 = 0xCE;
    top.signal_2_3 = 0xFA;

    do_eval();

    if(top.signal_2_flat != 0xFACEFEED) {
        test_failed("FLAT_EQUALS_NORMAL");
    }

    end();

    return 0;
}