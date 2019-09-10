extern debug_print(char value);

void main() {
    char a = 0;

    debug_print(a);

    char b = 1;

    while(b < 100) {
        debug_print(b);

        char old_b = b;

        b += a;

        a = old_b;
    }
}