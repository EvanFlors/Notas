#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Find Duplicates in a Unsorted Array
// This function finds and prints duplicate elements in a unsorted array.
//
// Given: A unsorted array of integers
// Returns: A list of duplicate integers
//
// Method 1: Brute Force        - O(n^2), O(1) space
// Method 2: Hashing            - O(n), O(n) space
//
// ════════════════════════════════════════════════════════════════════

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void FindDuplicates(Array *);
void FindDuplicatesHash(Array *);

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

    int count;

    for(int i = 0; i < arr->length - 1; i++) {
        count = 1;

        if (arr->data[i] == -1) {  // Skip already visited elements
            continue;
        }

        for(int j = i + 1; j < arr->length; j++) {
            if(arr->data[i] == arr->data[j]) {
                count++;
                arr->data[j] = -1;  // Mark as visited
            }
        }

        if(count > 1) {
            printf("Number %d appears %d times.\n", arr->data[i], count);
        }
    }

}

void FindDuplicatesHash(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    int max = arr->data[0];
    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] > max) {
            max = arr->data[i];
        }
    }

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
