#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VFlattenTest.h"
#include "shared.h"

int main(int argc, char *argv[]) { 
    VerilatedContext context{};
    context.commandArgs(argc, argv);

    VFlattenTest top(&context);

    top.signal_flat = 0xCAFEBABE;

    top.eval();

    if(top.signal_echo_0 != 0xBE || top.signal_echo_1 != 0xBA || top.signal_echo_2 != 0xFE || top.signal_echo_3 != 0xCA) {
        fprintf(stderr, "Test NORMAL_EQUALS_FLAT failed\n");
        return 1;
    }

    top.signal_2_0 = 0xED;
    top.signal_2_1 = 0xFE;
    top.signal_2_2 = 0xCE;
    top.signal_2_3 = 0xFA;

    top.eval();

    if(top.signal_2_flat != 0xFACEFEED) {
        fprintf(stderr, "Test FLAT_EQUALS_NORMAL failed\n");
        return 1;
    }

    return 0;
}