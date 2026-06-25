#include <stdio.h>
#include <stdlib.h>

int *BubbleSort(int arr[], int n);

void Swap(int *a, int *b);

int main() {

    int Arr[] = {5, 1, 4, 2, 8};
    int n = sizeof(Arr) / sizeof(Arr[0]);

    BubbleSort(Arr, n);

    for (int i = 0; i < n; i++) {
        printf("%d ", Arr[i]);
    }
    printf("\n");

    return 0;
}

int *BubbleSort(int arr[], int n) {
    int flag = 0;

    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                Swap(&arr[j], &arr[j + 1]);
                flag = 1;
            }
        }
        if (!flag) break;
    }

    return arr;
}

void Swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}