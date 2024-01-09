#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VStationValue.h"
#include "shared.h"

static void step(VerilatedContext *context, VStationValue *top) {
    top->clock = 1;

    top->eval();
    context->timeInc(1);

    top->clock = 0;

    top->eval();
    context->timeInc(1);
}

#define SIZE 32
#define STATION_INDEX_SIZE 2
#define BUS_COUNT 2

int main(int argc, char *argv[]) { 
    VerilatedContext context{};
    context.commandArgs(argc, argv);

    VStationValue top(&context);

    top.occupied = 0;
    top.preload_value = 0;
    top.source_index = 0;
    top.preloaded_value = 0;
    top.bus_asserted_flat = 0;
    top.bus_source_flat = 0;
    top.bus_value_flat = 0;

    top.reset = 1;
    step(&context, &top);

    top.reset = 0;
    step(&context, &top);

    if(top.occupied != 0) {
        fprintf(stderr, "Test reset failed\n");
        return 1;
    }

    top.occupied = 1;
    top.preload_value = 1;
    top.preloaded_value = 0xCAFEBABE;
    step(&context, &top);

    if(top.loaded != 1 || top.value != (IData)0xCAFEBABE) {
        fprintf(stderr, "Test set occupied preloaded failed\n");
        return 1;
    }

    top.occupied = 0;
    step(&context, &top);

    top.occupied = 1;
    top.preload_value = 0;
    top.source_index = 2;
    step(&context, &top);

    if(top.loaded != 0) {
        fprintf(stderr, "Test set occupied bus-loaded failed\n");
        return 1;
    }

    set_bit(&top.bus_asserted_flat, 1);
    set_sub_bits(&top.bus_source_flat, 1 * STATION_INDEX_SIZE, STATION_INDEX_SIZE, 2);
    set_sub_bits(&top.bus_value_flat, 1 * SIZE, SIZE, 0xFACEFEED);
    step(&context, &top);

    if(top.loaded != 1 || top.value != (IData)0xFACEFEED) {
        fprintf(stderr, "Test load value from bus failed\n");
        return 1;
    }

    return 0;
}