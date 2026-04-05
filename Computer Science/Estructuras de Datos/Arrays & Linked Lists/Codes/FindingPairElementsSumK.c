#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int size;
    int length;
} Array;

int main() {
    Array arr = {(int[8]){1, 2, 3, 3, 3, 5, 5, 6}, 8, 8};

    return 0;
}
