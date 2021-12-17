#include <stddef.h>
#include <stdio.h>

// #include "stubs/Lib_stub.h" // would contain the following:
extern void hs_init(int * argc, char ** argv[]);
extern char * hello();

int main(int argc, char ** argv) {
    // init GHCs runtime;
    hs_init(argc, argv); // or hs_init(NULL, NULL);
    // let's call our exported function.
    printf("%s\n", hello());
    return 0;
}