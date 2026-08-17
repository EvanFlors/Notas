#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *A;
    int n;
} Matrix;

void Set(Matrix *m, int i, int j, int x);
int Get(Matrix m, int i, int j);
void Display(Matrix m);

int main() {

    Matrix m;
    int i, j, x;

    printf("Enter Dimension: ");
    scanf("%d", &m.n);

    // Allocate 2n-1 elements (Toeplitz storage)
    m.A = (int *)malloc((2 * m.n - 1) * sizeof(int));

    // First row
    for (j = 0; j < m.n; j++) {
        printf("Enter element [%d, %d]: ", 0, j);
        scanf("%d", &x);
        Set(&m, 0, j, x);
    }

    // First column (excluding [0,0])
    for (i = 1; i < m.n; i++) {
        printf("Enter element [%d, %d]: ", i, 0);
        scanf("%d", &x);
        Set(&m, i, 0, x);
    }

    printf("\nFull Matrix:\n");
    Display(m);

    free(m.A);
    return 0;
}

void Set(Matrix *m, int i, int j, int x) {

    if (i <= j) {
        // Upper diagonals
        m->A[j - i] = x;
    } else {
        // Lower diagonals
        m->A[m->n + i - j - 1] = x;
    }
}

int Get(Matrix m, int i, int j) {

    if (i <= j) {
        return m.A[j - i];
    } else {
        return m.A[m.n + i - j - 1];
    }
}

void Display(Matrix m) {

    for (int i = 0; i < m.n; i++) {
        for (int j = 0; j < m.n; j++) {
            printf("%d ", Get(m, i, j));
        }
        printf("\n");
    }
}