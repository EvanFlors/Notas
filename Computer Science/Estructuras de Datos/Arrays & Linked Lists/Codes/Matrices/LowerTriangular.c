#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *A;
    int n;
} Matrix;

void Set(Matrix *, int, int, int);
int Get(Matrix, int, int);
void Display(Matrix);

int main() {

    Matrix m;
    int i, j, x;

    printf("Enter Dimension: ");
    scanf("%d", &m.n);

    m.A = (int *)malloc(m.n * (m.n + 1) / 2 * sizeof(int));

    for (i = 0; i < m.n; i++) {
        for (j = 0; j < m.n; j++) {
            if (i >= j) {
                printf("Enter element [%d, %d]: ", i, j);
                scanf("%d", &x);
                Set(&m, i, j, x);
            }
        }
    }

    Display(m);

    return 0;
}

void Set(Matrix *m, int i, int j, int x) {
    if (i >= j) {
        m->A[i * (i - 1) / 2 + j - 1] = x;
    }
}

int Get(Matrix m, int i, int j) {
    if (i >= j) {
        return m.A[i * (i - 1) / 2 + j - 1];
    }

    return 0;
}

void Display(Matrix m) {
    for(int i = 0; i < m.n; i++) {
        for(int j = 0; j < m.n; j++) {
            printf("%d ", Get(m, i, j));
        }
        printf("\n");
    }
}