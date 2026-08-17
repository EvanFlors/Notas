#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int i;
    int j;
    int x;
} Element;

typedef struct {
    int n;              // Number of rows
    int m;              // Number of columns
    int num;            // Number of non-zero elements
    Element *elements;  // Pointer to the array of non-zero elements
} SparseMatrix;

void Create(SparseMatrix *sm);
void Display(SparseMatrix sm);
SparseMatrix Add(SparseMatrix sm1, SparseMatrix sm2);

int main() {

    SparseMatrix sm;
    Create(&sm);
    Display(sm);

    return 0;
}

void Create(SparseMatrix *sm) {


    printf("Enter dimensions: ");
    scanf("%d %d", &sm->n, &sm->m);

    printf("Enter number of non-zero elements: ");
    scanf("%d", &sm->num);

    sm->elements = (Element *)malloc(sm->num * sizeof(Element));

    printf("Enter non-zero elements (i j x):\n");
    for (int k = 0; k < sm->num; k++) {
        scanf("%d %d %d", &sm->elements[k].i, &sm->elements[k].j, &sm->elements[k].x);
    }

}

SparseMatrix Add(SparseMatrix *sm1, SparseMatrix *sm2) {

    SparseMatrix *result;

    if (sm1->n != sm2->n || sm1->m != sm2->m) {
        return 0;
    }

    result = (SparseMatrix *)malloc(sizeof(SparseMatrix));
    result->n = sm1->n;
    result->m = sm1->m;
    result->num = 0;

    result->elements = (Element *)malloc((sm1->num + sm2->num) * sizeof(Element));

    int i = 0, j = 0, k = 0;
    while (i < sm1->num && j < sm2->num) {
        if (sm1->elements[i].i == sm2->elements[j].i && sm1->elements[i].j == sm2->elements[j].j) {
            result->elements[k].i = sm1->elements[i].i;
            result->elements[k].j = sm1->elements[i].j;
            result->elements[k].x = sm1->elements[i].x + sm2->elements[j].x;
            i++;
            j++;
        } else if (sm1->elements[i].i < sm2->elements[j].i || (sm1->elements[i].i == sm2->elements[j].i && sm1->elements[i].j < sm2->elements[j].j)) {
            result->elements[k] = sm1->elements[i];
            i++;
        } else {
            result->elements[k] = sm2->elements[j];
            j++;
        }
        k++;
    }

    result->num = k;
    return result;
}

void Display(SparseMatrix sm) {

    printf("\nSparse Matrix Representation:\n");

    int k = 0;
    for (int i = 0; i < sm.n; i++) {
        for (int j = 0; j < sm.m; j++) {
            if (k < sm.num && sm.elements[k].i == i && sm.elements[k].j == j) {
                printf("%d ", sm.elements[k].x);
                k++; // Keep track of the current non-zero element to display
            } else {
                printf("0 ");
            }
        }
        printf("\n");
    }

}