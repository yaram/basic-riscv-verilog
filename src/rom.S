.text

.global entry
entry:
    lui a0, %hi(test)
    addi a0, x0, %lo(test)

    addi a1, x0, 10
    
    sb a1, 0(a0)

    .loop:
        j .loop

test: .byte 0x0