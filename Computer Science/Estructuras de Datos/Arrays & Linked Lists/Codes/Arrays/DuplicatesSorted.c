#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Find Duplicates in a Sorted Array
// This function finds and prints duplicate elements in a sorted array.
//
// Given: A sorted array of integers
// Returns: A list of duplicate integers
//
// Method 1: Two Pointer Technique  — O(n), O(1) space
// Method 2: Hashing                — O(n), O(n) space
//
// ════════════════════════════════════════════════════════════════════

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void FindDuplicates(Array *arr);
void FindDuplicatesHash(Array *arr);

int main() {
    Array arr = {(int[8]){1, 2, 3, 3, 3, 5, 5, 6}, 8, 8};

    FindDuplicates(&arr);
    FindDuplicatesHash(&arr);

    return 0;
}

void FindDuplicates(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    // int lastDuplicate = 0;
    // for (int i = 0; i < arr->length - 1; i++) {
    //     if (arr->data[i] == arr->data[i + 1] && arr->data[i] != lastDuplicate) {
    //         printf("Duplicate found: %d\n", arr->data[i]);
    //         lastDuplicate = arr->data[i];
    //     }
    // }

    for (int i = 0, j = 0; i < arr->length - 1; i++) {
        if (arr->data[i] == arr->data[i + 1]) {
            j = i + 1;
            while (j < arr->length && arr->data[j] == arr->data[i]) {
                j++;
            }
            printf("Number %d appears %d times.\n", arr->data[i], j - i);
            i = j - 1;
        }
    }

}

void FindDuplicatesHash(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    int max = arr->data[arr->length - 1];
    int *hash = calloc(max + 1, sizeof(int));

    for (int i = 0; i < arr->length; i++) {
        hash[arr->data[i]]++;
    }

    for (int i = 0; i <= max; i++) {
        if (hash[i] > 1) {
            printf("Number %d appears %d times.\n", i, hash[i]);
        }
    }

    free(hash);
}