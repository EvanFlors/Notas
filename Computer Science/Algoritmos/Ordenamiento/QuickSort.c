#include <stdio.h>
#include <stdlib.h>

int *QuickSort(int arr[], int n);

void Swap(int *a, int *b);

int main() {

    int Arr[] = {5, 1, 4, 2, 8};
    int n = sizeof(Arr) / sizeof(Arr[0]);

    QuickSort(Arr, n);

    for (int i = 0; i < n; i++) {
        printf("%d ", Arr[i]);
    }
    printf("\n");

    return 0;
}

int *QuickSort(int arr[], int n) {

}

void Swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}