#include <stdio.h>
#include <stdlib.h>

void CountSort(int A[], int n);
int FindMax(int A[], int n);

int main() {
    int A[] = {4, 5, 1, 1, 7, 8, 2, 3, 6, 9, 2, 3};
    int n = sizeof(A) / sizeof(A[0]);

    CountSort(A, n);

    printf("Sorted array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", A[i]);
    }
    printf("\n");

    return 0;
}

void CountSort(int A[], int n) {

    int i, j;
    int max = FindMax(A, n);
    int *hash = (int *) calloc(max + 1, sizeof(int));

    for (i = 0; i < n; i++) {
        hash[A[i]]++;
    }

    i = j = 0;
    while (i < max + 1) {
        if (hash[i] > 0) {
            A[j++] = i;
            hash[i]--;
        } else {
            i++;
        }
    }
}

int FindMax(int A[], int n) {
    int max = A[0];
    for (int i = 1; i < n; i++) {
        if (A[i] > max) {
            max = A[i];
        }
    }
    return max;
}