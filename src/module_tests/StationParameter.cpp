#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VStationParameter.h"
#define MODULE_NAME StationParameter
#define MODULE_IS_CLOCKED
#include "shared.h"

#define SIZE 32
#define STATION_INDEX_SIZE 2
#define BUS_COUNT 2

int main(int argc, char *argv[]) { 
    init();

    top.occupied = 0;
    top.preload_value = 0;
    top.source_index = 0;
    top.preloaded_value = 0;
    top.bus_asserted[0] = 0;
    top.bus_source[0] = 0;
    top.bus_value[0] = 0;
    top.bus_asserted[1] = 0;
    top.bus_source[1] = 0;
    top.bus_value[1] = 0;

    top.reset = 1;
    step();

    top.reset = 0;
    step();

    if(top.occupied != 0) {
        test_failed("reset");
    }

    top.occupied = 1;
    top.preload_value = 1;
    top.preloaded_value = 0xCAFEBABE;
    step();

    if(top.loaded != 1 || top.value != (IData)0xCAFEBABE) {
        test_failed("set occupied preloaded");
    }

    top.occupied = 0;
    step();

    top.occupied = 1;
    top.preload_value = 0;
    top.source_index = 2;
    step();

    if(top.loaded != 0) {
        test_failed("set occupied bus-loaded");
    }

    top.bus_asserted[1] = 1;
    top.bus_source[1] = 2;
    top.bus_value[1] = 0xFACEFEED;
    step();

    if(top.loaded != 1 || top.value != (IData)0xFACEFEED) {
        test_failed("load value from bus");
    }

    end();

    return 0;
}