#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void findMinMax(Array *);

int main() {
    Array arr = {(int[8]){0, 1, 2, 3, 5, 6}, 6, 6};

    findMinMax(&arr);

    return 0;
}

void findMinMax(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Array is empty or NULL\n");
        return;
    }

    int min = arr->data[0];
    int max = arr->data[0];

    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] < min) {
            min = arr->data[i];
        }
        if (arr->data[i] > max) {
            max = arr->data[i];
        }
    }

    printf("Min: %d, Max: %d\n", min, max);
}