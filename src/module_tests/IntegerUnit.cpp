#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VIntegerUnit.h"
#include "shared.h"

static void step(VerilatedContext *context, VIntegerUnit *top) {
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

    VIntegerUnit top(&context);

    top.set_occupied = 0;
    top.reset_occupied = 0;
    top.operation = 0;
    top.preload_a_value = 0;
    top.a_source = 0;
    top.preloaded_a_value = 0;
    top.preload_b_value = 0;
    top.b_source = 0;
    top.preloaded_b_value = 0;
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

    top.set_occupied = 1;
    top.operation = 0;
    top.preload_a_value = 1;
    top.preloaded_a_value = 20;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)20 + (IData)40) {
        fprintf(stderr, "Test set_occupied preloaded failed\n");
        return 1;
    }

    top.set_occupied = 0;
    step(&context, &top);

    if(top.occupied != 1) {
        fprintf(stderr, "Test unset set_occupied failed\n");
        return 1;
    }

    top.reset_occupied = 1;
    step(&context, &top);

    if(top.occupied != 0) {
        fprintf(stderr, "Test set reset_occupied failed\n");
        return 1;
    }

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 0;
    top.preload_a_value = 1;
    top.preloaded_a_value = 30;
    top.preload_b_value = 0;
    top.b_source = 2;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 0) {
        fprintf(stderr, "Test set_occupied preloaded A bus-loaded B failed\n");
        return 1;
    }

    top.set_occupied = 0;
    set_bit(&top.bus_asserted_flat, 1);
    set_sub_bits(&top.bus_source_flat, 1 * STATION_INDEX_SIZE, STATION_INDEX_SIZE, 2);
    set_sub_bits(&top.bus_value_flat, 1 * SIZE, SIZE, 50);
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)30 + (IData)50) {
        fprintf(stderr, "Test load B value from bus failed\n");
        return 1;
    }

    unset_bit(&top.bus_asserted_flat, 1);
    step(&context, &top);

    if(top.result_ready != 1 || top.result != 80) {
        fprintf(stderr, "Test load B value from bus failed\n");
        return 1;
    }

    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 0;
    top.preload_a_value = 0;
    top.a_source = 1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 0) {
        fprintf(stderr, "Test set_occupied bus-loaded A preloaded B failed\n");
        return 1;
    }

    top.set_occupied = 0;
    set_bit(&top.bus_asserted_flat, 0);
    set_sub_bits(&top.bus_source_flat, 0 * STATION_INDEX_SIZE, STATION_INDEX_SIZE, 1);
    set_sub_bits(&top.bus_value_flat, 0 * SIZE, SIZE, 60);
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)40 + (IData)60) {
        fprintf(stderr, "Test load A value from bus failed\n");
        return 1;
    }

    top.reset_occupied = 1;
    unset_bit(&top.bus_asserted_flat, 0);
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 1;
    top.preload_a_value = 1;
    top.preloaded_a_value = 20;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)20 - (IData)40) {
        fprintf(stderr, "Test subtract failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 2;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != ((IData)0xFF0 | (IData)0x0FF)) {
        fprintf(stderr, "Test or failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 3;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != ((IData)0xFF0 & (IData)0x0FF)) {
        fprintf(stderr, "Test and failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 4;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != ((IData)0xFF0 ^ (IData)0x0FF)) {
        fprintf(stderr, "Test xor failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 5;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != ((IData)0xF << (IData)5)) {
        fprintf(stderr, "Test left shift failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 6;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != ((IData)0xF >> (IData)5)) {
        fprintf(stderr, "Test right shift failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 7;
    top.preload_a_value = 1;
    top.preloaded_a_value = -1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)((int32_t)-1 >> (int32_t)5)) {
        fprintf(stderr, "Test right arithmetic shift failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 8;
    top.preload_a_value = 1;
    top.preloaded_a_value = -1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)((IData)-1 < (IData)5)) {
        fprintf(stderr, "Test unsigned less than failed\n");
        return 1;
    }

    top.set_occupied = 0;
    top.reset_occupied = 1;
    step(&context, &top);

    top.set_occupied = 1;
    top.reset_occupied = 0;
    top.operation = 9;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFFFFFFFF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step(&context, &top);

    if(top.occupied != 1 || top.result_ready != 1 || top.result != (IData)((int32_t)-1 < (int32_t)5)) {
        fprintf(stderr, "Test signed less than failed\n");
        return 1;
    }

    return 0;
}