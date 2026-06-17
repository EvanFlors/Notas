#include <stdio.h>
#include <stdlib.h>

void ShellSort(int A[], int n);
void Swap(int *a, int *b);

int main() {

    int A[] = {6, 5, 10, 4, 2, 9, 12, 16, 8, 13, 3};
    int n = sizeof(A) / sizeof(A[0]);

    ShellSort(A, n);

    printf("Sorted array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", A[i]);
    }
    printf("\n");

    return 0;
}

void ShellSort(int array[], int size)
{
    for (int gap = size / 2; gap > 0; gap /= 2)
    {
        for (int current = gap; current < size; current++)
        {
            int value = array[current];
            int position = current;

            while (
                position >= gap &&
                array[position - gap] > value
            )
            {
                array[position] = array[position - gap];
                position -= gap;
            }

            array[position] = value;
        }
    }
}

void Swap(int *a, int *b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}