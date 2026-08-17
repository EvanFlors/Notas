#include <stdio.h>
#include <stdlib.h>

void QuickSort(int arr[], int l, int h);
int Partition(int arr[], int l, int h);

void Swap(int *a, int *b);

int main() {

    int Arr[] = {5, 1, 4, 2, 8, INT32_MAX};
    int n = sizeof(Arr) / sizeof(Arr[0]);

    QuickSort(Arr, 0, n - 1);

    for (int i = 0; i < n - 1; i++) {
        printf("%d ", Arr[i]);
    }
    printf("\n");

    return 0;
}

void QuickSort(int arr[], int l, int h) {

    int j;
    if (l < h) {
        j = Partition(arr, l, h);
        QuickSort(arr, l, j);
        QuickSort(arr, j + 1, h);
    }
}

int Partition(int arr[], int l, int h) {

    int pivot = arr[l];
    int i = l, j = h;

    do {
        do {
            i++;
        } while (arr[i] <= pivot);

        do {
            j--;
        } while (arr[j] > pivot);

        if (i < j) {
            Swap(&arr[i], &arr[j]);
        }
    } while (i < j);

    Swap(&arr[l], &arr[j]);

    return j;
}

void Swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}