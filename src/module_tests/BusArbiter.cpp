#include <math.h>
#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VBusArbiter.h"
#define MODULE_NAME BusArbiter
#include "shared.h"

#define SIZE 32
#define STATION_COUNT 4
#define STATION_INDEX_SIZE 2
#define BUS_COUNT 2

int main(int argc, char *argv[]) { 
    init();

    top.station_ready[0] = 0;
    top.station_ready[1] = 0;
    top.station_ready[2] = 0;
    top.station_ready[3] = 0;
    do_eval();

    if(top.bus_asserted[0] != 0 || top.bus_asserted[1] != 0) {
        test_failed("no assertions");
    }

    top.station_ready[1] = 1;
    top.station_value[1] = 0xCAFEBABE;
    do_eval();

    if(
        top.bus_asserted[0] != 1 ||
        top.bus_source[0] != 1 ||
        top.bus_value[0] != 0xCAFEBABE ||
        top.bus_asserted[1] != 0 ||
        top.station_is_asserting[0] != 0 ||
        top.station_is_asserting[1] != 1 ||
        top.station_is_asserting[2] != 0 ||
        top.station_is_asserting[3] != 0
    ) {
        test_failed("single station");
    }

    top.station_ready[0] = 1;
    top.station_value[0] = 0xFACEFEED;
    do_eval();

    if(
        top.bus_asserted[0] != 1 ||
        top.bus_source[0] != 0 ||
        top.bus_value[0] != 0xFACEFEED ||
        top.bus_asserted[1] != 1 ||
        top.bus_source[1] != 1 ||
        top.bus_value[1] != 0xCAFEBABE ||
        top.station_is_asserting[0] != 1 ||
        top.station_is_asserting[1] != 1 ||
        top.station_is_asserting[2] != 0 ||
        top.station_is_asserting[3] != 0
    ) {
        test_failed("multiple station");
    }

    top.station_ready[2] = 1;
    top.station_value[2] = 0xFFFFFFFF;
    do_eval();

    if(
        top.bus_asserted[0] != 1 ||
        top.bus_source[0] != 0 ||
        top.bus_value[0] != 0xFACEFEED ||
        top.bus_asserted[1] != 1 ||
        top.bus_source[1] != 1 ||
        top.bus_value[1] != 0xCAFEBABE ||
        top.station_is_asserting[0] != 1 ||
        top.station_is_asserting[1] != 1 ||
        top.station_is_asserting[2] != 0 ||
        top.station_is_asserting[3] != 0
    ) {
        test_failed("multiple station contention");
    }

    end();

    return 0;
}