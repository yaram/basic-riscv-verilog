#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VIntegerUnit.h"
#define MODULE_NAME IntegerUnit
#define MODULE_IS_CLOCKED
#include "shared.h"

#define SIZE 32
#define STATION_INDEX_SIZE 2
#define BUS_COUNT 2

int main(int argc, char *argv[]) { 
    init();

    top.occupied = 0;
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
    step();

    top.reset = 0;
    step();

    if(top.occupied != 0) {
        test_failed("reset");
    }

    top.occupied = 1;
    top.operation = 0;
    top.preload_a_value = 1;
    top.preloaded_a_value = 20;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step();

    if(top.result_ready != 1 || top.result != (IData)20 + (IData)40) {
        test_failed("set occupied preloaded");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 0;
    top.preload_a_value = 1;
    top.preloaded_a_value = 30;
    top.preload_b_value = 0;
    top.b_source = 2;
    step();

    if(top.result_ready != 0) {
        test_failed("set occupied preloaded A bus-loaded B");
    }

    set_bit(&top.bus_asserted_flat, 1);
    set_sub_bits(&top.bus_source_flat, 1 * STATION_INDEX_SIZE, STATION_INDEX_SIZE, 2);
    set_sub_bits(&top.bus_value_flat, 1 * SIZE, SIZE, 50);
    step();

    if(top.result_ready != 1 || top.result != (IData)30 + (IData)50) {
        test_failed("load B value from bus");
    }

    unset_bit(&top.bus_asserted_flat, 1);
    step();

    if(top.result_ready != 1 || top.result != 80) {
        test_failed("load B value from bus");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 0;
    top.preload_a_value = 0;
    top.a_source = 1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step();

    if(top.result_ready != 0) {
        test_failed("set occupied bus-loaded A preloaded B");
    }

    set_bit(&top.bus_asserted_flat, 0);
    set_sub_bits(&top.bus_source_flat, 0 * STATION_INDEX_SIZE, STATION_INDEX_SIZE, 1);
    set_sub_bits(&top.bus_value_flat, 0 * SIZE, SIZE, 60);
    step();

    if(top.result_ready != 1 || top.result != (IData)40 + (IData)60) {
        test_failed("load A value from bus");
    }

    top.occupied = 0;
    unset_bit(&top.bus_asserted_flat, 0);
    step();

    top.occupied = 1;
    top.operation = 1;
    top.preload_a_value = 1;
    top.preloaded_a_value = 20;
    top.preload_b_value = 1;
    top.preloaded_b_value = 40;
    step();

    if(top.result_ready != 1 || top.result != (IData)20 - (IData)40) {
        test_failed("subtract");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 2;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step();

    if(top.result_ready != 1 || top.result != ((IData)0xFF0 | (IData)0x0FF)) {
        test_failed("or");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 3;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step();

    if(top.result_ready != 1 || top.result != ((IData)0xFF0 & (IData)0x0FF)) {
        test_failed("and");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 4;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFF0;
    top.preload_b_value = 1;
    top.preloaded_b_value = 0x0FF;
    step();

    if(top.result_ready != 1 || top.result != ((IData)0xFF0 ^ (IData)0x0FF)) {
        test_failed("xor");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 5;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step();

    if(top.result_ready != 1 || top.result != ((IData)0xF << (IData)5)) {
        test_failed("left shift");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 6;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step();

    if(top.result_ready != 1 || top.result != ((IData)0xF >> (IData)5)) {
        test_failed("right shift");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 7;
    top.preload_a_value = 1;
    top.preloaded_a_value = -1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step();

    if(top.result_ready != 1 || top.result != (IData)((int32_t)-1 >> (int32_t)5)) {
        test_failed("right arithmetic shift");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 8;
    top.preload_a_value = 1;
    top.preloaded_a_value = -1;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step();

    if(top.result_ready != 1 || top.result != (IData)((IData)-1 < (IData)5)) {
        test_failed("unsigned less than");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.operation = 9;
    top.preload_a_value = 1;
    top.preloaded_a_value = 0xFFFFFFFF;
    top.preload_b_value = 1;
    top.preloaded_b_value = 5;
    step();

    if(top.result_ready != 1 || top.result != (IData)((int32_t)-1 < (int32_t)5)) {
        test_failed("signed less than");
    }

    end();

    return 0;
}