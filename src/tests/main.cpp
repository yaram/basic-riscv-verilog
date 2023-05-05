#define VL_TIME_CONTEXT
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "VTestbench.h"

int main(int argc, char *argv[]) { 
    VerilatedContext context{};
    context.commandArgs(argc, argv);
    context.fatalOnError(false);
    context.traceEverOn(true);

    VerilatedVcdC vcd_context {};

    VTestbench top(&context);
    top.trace(&vcd_context, 2);

    vcd_context.open("Testbench.vcd");

    top.reset = 1;
    top.clock = 0;

    while(!context.gotFinish()) {
        if(context.time() == 10) {
            top.reset = 0;
        }

        top.clock = !top.clock;

        top.eval();

        vcd_context.dump(context.time());

        context.timeInc(1);
    }

    top.final();

    vcd_context.close();

    if(context.gotError()) {
        return 1;
    }

    return 0;
}