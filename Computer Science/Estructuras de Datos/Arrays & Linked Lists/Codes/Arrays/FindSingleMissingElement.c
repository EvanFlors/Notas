#include <stdio.h>
#include <stdlib.h>

// ═══════════════════════════════════════════════
//  Finding a Single Missing Element
//  in a Sorted Array of Natural Numbers
//
//  Given: sorted array with ONE missing element in range [lo..hi]
//  Find:  the missing value
//
//  Method 1: Sum formula     — O(n), O(1) space  (any range)
//  Method 2: Difference      — O(n), O(1) space  (sorted only)
// ═══════════════════════════════════════════════

typedef struct {
    int *data;
    int size;
    int length;
} Array;

int FindMissingSum(Array *arr);
int FindMissingDiff(Array *arr);

int main(void) {
    // Range [1..8], missing 4
    Array arr1 = {(int[7]){1, 2, 3, 5, 6, 7, 8}, 7, 7};

    // Range [6..13], missing 10
    Array arr2 = {(int[7]){6, 7, 8, 9, 11, 12, 13}, 7, 7};

    printf("── Method 1: Sum Formula ──\n");
    printf("Missing in [1..8]:  %d\n", FindMissingSum(&arr1));
    printf("Missing in [6..13]: %d\n", FindMissingSum(&arr2));

    printf("\n── Method 2: Difference ──\n");
    printf("Missing in [1..8]:  %d\n", FindMissingDiff(&arr1));
    printf("Missing in [6..13]: %d\n", FindMissingDiff(&arr2));

    return 0;
}

// ─────────────────────────────────────────────
//  Method 1: Sum Formula (works for any range)
//
//  Idea: The complete range [lo..hi] has n+1 elements.
//        Expected sum = (n+1)(lo+hi)/2
//        Actual sum   = sum of array elements
//        Missing      = expected - actual
//
//  Time:  O(n)
//  Space: O(1)
// ─────────────────────────────────────────────
int FindMissingSum(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return -1;
    }

    int lo = arr->data[0];
    int hi = arr->data[arr->length - 1];

    // Expected sum of complete range [lo..hi] = (count)(lo+hi)/2
    // count = hi - lo + 1 = arr->length + 1 (one is missing)
    int expectedSum = (arr->length + 1) * (lo + hi) / 2;

    int actualSum = 0;
    for (int i = 0; i < arr->length; i++) {
        actualSum += arr->data[i];
    }

    return expectedSum - actualSum;
}

// ─────────────────────────────────────────────
//  Method 2: Difference (sorted arrays only)
//
//  Idea: In a sorted sequence with no gaps,
//        arr[i] - i is constant (= arr[0]).
//        When the difference changes, the gap is found.
//
//  Time:  O(n)
//  Space: O(1)
// ─────────────────────────────────────────────
int FindMissingDiff(Array *arr) {
    if (arr == NULL || arr->length == 0) {
        printf("Invalid array.\n");
        return -1;
    }

    int diff = arr->data[0];  // expected: arr[0] - 0

    for (int i = 0; i < arr->length; i++) {
        if (arr->data[i] - i != diff) {
            return diff + i;  // the value that should have been here
        }
    }

    return -1;  // no missing element found
}