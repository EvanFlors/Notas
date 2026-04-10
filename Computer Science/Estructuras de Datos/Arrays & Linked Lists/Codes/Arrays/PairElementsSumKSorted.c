#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void findPairsWithSumK(Array *, int);

int main() {
    Array arr = {(int[8]){0, 1, 2, 3, 5, 6}, 6, 6};

    findPairsWithSumK(&arr, 6);

    return 0;
}


void findPairsWithSumK(Array *arr, int k) {

    int i = 0, j = arr->length - 1;

    while (i < j) {
        int sum = arr->data[i] + arr->data[j];
        if (sum == k) {
            printf("Pair found: (%d, %d)\n", arr->data[i], arr->data[j]);
            i++;
            j--;
        } else if (sum < k) {
            i++;
        } else {
            j--;
        }
    }

}
