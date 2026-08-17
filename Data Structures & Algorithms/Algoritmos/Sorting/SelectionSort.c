#include <stdio.h>
#include <stdlib.h>

int *SelectionSort(int arr[], int n);

void Swap(int *a, int *b);

int main() {

    int Arr[] = {5, 1, 4, 2, 8};
    int n = sizeof(Arr) / sizeof(Arr[0]);

    SelectionSort(Arr, n);

    for (int i = 0; i < n; i++) {
        printf("%d ", Arr[i]);
    }
    printf("\n");

    return 0;
}

int *SelectionSort(int arr[], int n) {

    int i, j, k;

    for (i = 0; i < n - 1; i++) {
        for (j = k = i; j < n; j++) {
            if (arr[j] < arr[k]) {
                k = j;
            }
        }
        Swap(&arr[i], &arr[k]);
    }

    return arr;
}

void Swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}