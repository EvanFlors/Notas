#include <stdio.h>
#include <stdlib.h>

// ═══════════════════════════════════════════════
//  Finding Multiple Missing Elements
//  in a Sorted Array of Natural Numbers
//
//  Given: sorted array with elements in range [lo..hi]
//  Find:  all values in [lo..hi] NOT in the array
//
//  Method 1: Difference method    — O(n + k), O(1) space
//  Method 2: Hash table method    — O(n + range), O(range) space
//  (where k = number of missing elements)
// ═══════════════════════════════════════════════

typedef struct {
    int *data;
    int size;
    int length;
} Array;

void FindMissingDiff(Array *arr);
void FindMissingHash(Array *arr);

int main(void) {
    // Sorted array: elements in range [1..10], missing 3, 7, 10
    Array arr = {(int[7]){1, 2, 4, 5, 6, 8, 9}, 7, 7};

    printf("── Method 1: Difference ──\n");
    FindMissingDiff(&arr);

    printf("\n── Method 2: Hash Table ──\n");
    FindMissingHash(&arr);

    return 0;
}

// ─────────────────────────────────────────────
//  Method 1: Difference (sorted arrays only)
//
//  Idea: In a complete sequence [1,2,3,...],
//        arr[i] - i should be constant (= arr[0]).
//        When the difference increases, values were skipped.
//
//  Time:  O(n)
//  Space: O(1)
// ─────────────────────────────────────────────
void FindMissingDiff(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    int diff = arr->data[0] - 0;  // expected: arr[0] (e.g. 1)

    for (int i = 0; i < arr->length; i++) {
        int currentDiff = arr->data[i] - i;
        if (currentDiff != diff) {
            // Fill in all missing values between old diff and new diff
            while (diff < currentDiff) {
                printf("Missing: %d\n", diff + i);
                diff++;
            }
        }
    }
}

// ─────────────────────────────────────────────
//  Method 2: Hash Table (works for any order)
//
//  Idea: Mark every element present in a boolean table,
//        then scan the range for unmarked positions.
//
//  Time:  O(n + range)
//  Space: O(range) where range = max - min + 1
// ─────────────────────────────────────────────
void FindMissingHash(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return;
    }

    // Find the actual range of values
    int lo = arr->data[0], hi = arr->data[0];
    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] < lo) lo = arr->data[i];
        if (arr->data[i] > hi) hi = arr->data[i];
    }

    int range = hi - lo + 1;
    int *hash = (int *)calloc(range, sizeof(int));
    if (hash == NULL) {
        printf("Memory allocation failed.\n");
        return;
    }

    // Mark present elements
    for (int i = 0; i < arr->length; i++) {
        hash[arr->data[i] - lo] = 1;
    }

    // Report missing elements
    for (int i = 0; i < range; i++) {
        if (hash[i] == 0) {
            printf("Missing: %d\n", i + lo);
        }
    }

    free(hash);
}