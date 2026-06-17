#include <stdio.h>
#include <stdlib.h>

static int min(int a, int b);
static void Merge(int A[], int B[], int left, int mid, int right);

void IterativeMergeSort(int A[], int n);
void RecursiveMergeSort(int A[], int B[], int l, int h);

int main(void)
{
    int A[] = {4, 5, 1, 7, 8, 2, 3, 6, 9};
    int n = sizeof(A) / sizeof(A[0]);

    int *B = malloc(n * sizeof(int));
    if (B == NULL)
    {
        fprintf(stderr, "Memory allocation failed\n");
        return EXIT_FAILURE;
    }

    RecursiveMergeSort(A, B, 0, n - 1);

    printf("Sorted array: ");
    for (int i = 0; i < n; i++)
    {
        printf("%d ", A[i]);
    }
    printf("\n");

    free(B);

    return 0;
}

static int min(int a, int b)
{
    return (a < b) ? a : b;
}

static void Merge(int A[], int B[], int left, int mid, int right)
{
    int i = left;
    int j = mid + 1;
    int k = left;

    while (i <= mid && j <= right)
    {
        if (A[i] <= A[j])
        {
            B[k++] = A[i++];
        }
        else
        {
            B[k++] = A[j++];
        }
    }

    while (i <= mid)
    {
        B[k++] = A[i++];
    }

    while (j <= right)
    {
        B[k++] = A[j++];
    }

    for (i = left; i <= right; i++)
    {
        A[i] = B[i];
    }
}

void IterativeMergeSort(int A[], int n)
{
    if (n <= 1)
    {
        return;
    }

    int *B = malloc(n * sizeof(int));

    if (B == NULL)
    {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }

    for (int run_size = 1; run_size < n; run_size *= 2)
    {
        for (int left = 0; left < n - 1; left += 2 * run_size)
        {
            int mid = min(left + run_size - 1, n - 1);
            int right = min(left + (2 * run_size) - 1, n - 1);

            if (mid < right)
            {
                Merge(A, B, left, mid, right);
            }
        }
    }

    free(B);
}

void RecursiveMergeSort(int A[], int B[], int l, int h) {
    // Stop condition
    if (l >= h) {
        return;
    }

    int mid = l + (h - l) / 2;

    // Tree traversal
    RecursiveMergeSort(A, B, l, mid);
    RecursiveMergeSort(A, B, mid + 1, h);

    // Postorder
    Merge(A, B, l, mid, h);
}