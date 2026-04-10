#include <stdio.h>
#include <stdlib.h>

// ═══════════════════════════════════════════════
//
//  Finding a pair of numbers that sum to a target value
//  from a unsorted array of integers
//
//  Given: a unsorted array of integers
//  Find:  all pairs (i, j) such that arr[i] + arr[j] = k
//
//  Method 1: Brute-force approach  - O(n^2), O(1) space
//  Method 2: Hash table approach   - O(n), O(n) space
//
// ═══════════════════════════════════════════════

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void findPairsWithSumKLoops(Array *, int);
void findPairsWithSumKHash(Array *, int);

int findMax(Array *);

int main() {
    Array arr = {(int[8]){0, 1, 2, 3, 5, 6}, 7, 7};

    findPairsWithSumKHash(&arr, 6);

    return 0;
}

int findMax(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return -1;
    }

    int max = arr->data[0];
    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] > max) {
            max = arr->data[i];
        }
    }
    return max;
}

void findPairsWithSumKLoops(Array *arr, int k) {
    for (int i = 0; i < arr->length; i++) {
        for (int j = i + 1; j < arr->length; j++) {
            if (arr->data[i] + arr->data[j] == k) {
                printf("Pair found: (%d, %d)\n", arr->data[i], arr->data[j]);
            }
        }
    }
}

void findPairsWithSumKHash(Array *arr, int k) {

    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    int max = findMax(arr);
    if (max == -1) {
        return;
    }

    // Create a hash table to store elements
    int *hashTable = (int *)calloc(max + 1, sizeof(int));
    if (hashTable == NULL) {
        printf("Memory allocation failed.\n");
        return;
    }

    // Find pairs using the hash table
    for (int i = 0; i < arr->length; i++) {
        int complement = k - arr->data[i];
        if (complement >= 0 && hashTable[complement] > 0) {
            printf("Pair found: (%d, %d)\n", arr->data[i], complement);
        }
        hashTable[arr->data[i]]++;
    }

    free(hashTable);
}