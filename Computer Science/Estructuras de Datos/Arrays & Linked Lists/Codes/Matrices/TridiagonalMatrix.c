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

    m.A = (int *)malloc((3 * m.n - 2) * sizeof(int));

    for (i = 0; i < m.n; i++) {
        for (j = 0; j < m.n; j++) {
            if (abs(i - j) <= 1) {
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
    int value = abs(i - j);

    switch (value) {
        case 0: // Lower diagonal
            m->A[i] = x;
            break;
        case 1: // Upper diagonal
            m->A[m->n + i - 2] = x;
            break;
        case -1: // Main diagonal
            m->A[2 * m->n + i - 2] = x;
            break;
    }
}

int Get(Matrix m, int i, int j) {
    int value = abs(i - j);

    switch (value) {
        case 0: // Lower diagonal
            return m.A[i];
        case 1: // Upper diagonal
            return m.A[m.n + i - 2];
        case -1: // Main diagonal
            return m.A[2 * m.n + i - 2];
        default:
            return 0;
    }
}

void Display(Matrix m) {
    for(int i = 0; i < m.n; i++) {
        for(int j = 0; j < m.n; j++) {
            printf("%d ", Get(m, i, j));
        }
        printf("\n");
    }
}