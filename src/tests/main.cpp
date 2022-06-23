#include "VTestbench.h"
#include "verilated.h"

int main(int argc, char *argv[]) { 
    VerilatedContext context{};
    context.commandArgs(argc, argv);
    context.fatalOnError(false);

    VTestbench top(&context);

    top.reset = 1;
    top.clock = 0;

    uint64_t time_step = 0;
    while(!context.gotFinish()) {
        if(time_step == 10) {
            top.reset = 0;
        }

        top.clock = !top.clock;

        top.eval();

        context.timeInc(1);
        time_step += 1;
    }

    top.final();

    if(context.gotError()) {
        return 1;
    }

    return 0;
}