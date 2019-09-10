ENTRY(entry)

SECTIONS {
    . = 0;

    .text : {
        *(.text.entry)
        *(.text)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
    }
}