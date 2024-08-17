#pragma once

#if defined(TRACING)
#include "verilated_vcd_c.h"
#endif

#if !defined(MODULE_NAME)
    #error "Must define MODULE_NAME"
#endif

#define CONCATENATE_INNER(A, B) A ## B
#define CONCATENATE(A, B) CONCATENATE_INNER(A, B)

#define STRING_CONCATENATE_INNER(A, B) A B
#define STRING_CONCATENATE(A, B) STRING_CONCATENATE_INNER(A, B)

#define STRINGIFY_INNER(DEF) #DEF
#define STRINGIFY(DEF) STRINGIFY_INNER(DEF)

#define MODULE_CLASS CONCATENATE(V, MODULE_NAME)

#if defined(TRACING)

#define MODULE_VCD_FILE STRING_CONCATENATE(STRINGIFY(MODULE_NAME), ".vcd")

#define init() VerilatedContext context{}; \
    context.commandArgs(argc, argv); \
    context.traceEverOn(true); \
    VerilatedVcdC vcd_context {}; \
    MODULE_CLASS top(&context); \
    top.trace(&vcd_context, 2); \
    vcd_context.open(MODULE_VCD_FILE);

#define do_eval() eval_(&context, &vcd_context, &top)
static inline void eval_(VerilatedContext *context, VerilatedVcdC *vcd_context, MODULE_CLASS *top) {
    top->eval();
    context->timeInc(1);
    vcd_context->dump(context->time());
}

#if defined(MODULE_IS_CLOCKED)
#define step() step_(&context, &vcd_context, &top)
static inline void step_(VerilatedContext *context, VerilatedVcdC *vcd_context, MODULE_CLASS *top) {
    top->clock = 1;

    eval_(context, vcd_context, top);

    top->clock = 0;

    eval_(context, vcd_context, top);
}
#endif

#define test_failed(name) test_failed_(&vcd_context, name)
[[noreturn]]
static inline void test_failed_(VerilatedVcdC *vcd_context, const char *name) {
    fprintf(stderr, "Test %s failed\n", name);

    vcd_context->close();

    exit(1);
}

#define end() end_(&vcd_context)
static inline void end_(VerilatedVcdC *vcd_context) {
    vcd_context->close();
}

#else

#define init() VerilatedContext context{}; \
    context.commandArgs(argc, argv); \
    MODULE_CLASS top(&context);

#define do_eval() eval_(&context, &top)
static inline void eval_(VerilatedContext *context, MODULE_CLASS *top) {
    top->eval();
    context->timeInc(1);
}

#if defined(MODULE_IS_CLOCKED)
#define step() step_(&context, &top)
static inline void step_(VerilatedContext *context, MODULE_CLASS *top) {
    top->clock = 1;

    eval_(context, top);

    top->clock = 0;

    eval_(context, top);
}
#endif

#define test_failed(name) test_failed_(name)
[[noreturn]]
static inline void test_failed_(const char *name) {
    fprintf(stderr, "Test %s failed\n", name);

    exit(1);
}

#define end()

#endif