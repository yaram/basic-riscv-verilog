.section .text.entry

.extern main

.global entry
entry:
    li sp, 0x10000

    call main

    .loop:
        j .loop

.text

.global debug_print
debug_print:
    li t0, 0xFFFFFF

    sb a0, (t0)

    ret