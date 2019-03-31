void __attribute__((noreturn)) entry(void){
    short *test = (short*)(0x1000);

    *test = 100;

    while(1);
}