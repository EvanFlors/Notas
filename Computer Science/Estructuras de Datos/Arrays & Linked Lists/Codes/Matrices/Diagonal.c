#include <stdio.h>

#define MAX 100

typedef struct {
    int A[MAX];
    int n;
} Matrix;

void Set(Matrix *, int, int, int);
int Get(Matrix, int, int);
void Display(Matrix);

int main() {

    Matrix m;
    m.n = 4;

    Set(&m, 0, 0, 1);
    Set(&m, 1, 1, 2);
    Set(&m, 2, 2, 3);
    Set(&m, 3, 3, 4);

    Display(m);

    return 0;
}

void Set(Matrix *m, int i, int j, int x) {
    if (i == j) {
        m->A[i] = x;
    }
}

int Get(Matrix m, int i, int j) {
    if (i == j) {
        return m.A[i];
    } else {
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