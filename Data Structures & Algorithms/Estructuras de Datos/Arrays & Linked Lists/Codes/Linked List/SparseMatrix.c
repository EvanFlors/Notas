#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int column;
    int value;
    struct Node *next;
} Node;

typedef struct {
    Node **rows;
    int m;
    int n;
} SparseMatrix;

void Create(SparseMatrix *);
void Insert(SparseMatrix *, int, int, int);
void Display(SparseMatrix *);

int main() {

    SparseMatrix matrix;
    Create(&matrix);
    Display(&matrix);

    return 0;
}

void Create(SparseMatrix *mat) {

    printf("Enter the number of rows and columns: ");
    scanf("%d %d", &mat->m, &mat->n);

    mat->rows = (Node **)calloc(mat->m, sizeof(Node *));

    printf("Enter the non-zero elements (row column value), -1 -1 -1 to stop:\n");
    int row, col, value;
    while (1) {
        scanf("%d %d %d", &row, &col, &value);
        if (row == -1 && col == -1 && value == -1) {
            break;
        }
        if (row >= 0 && row < mat->m && col >= 0 && col < mat->n) {
            Insert(mat, row, col, value);
        }
    }
}

void Insert(SparseMatrix *mat, int row, int col, int value) {

    Node *newNode = (Node *)malloc(sizeof(Node));
    newNode->column = col;
    newNode->value = value;
    newNode->next = NULL;

    if (mat->rows[row] == NULL) {
        mat->rows[row] = newNode;
    } else {
        Node *current = mat->rows[row];
        Node *prev = NULL;

        while (current && current->column < col) {
            prev = current;
            current = current->next;
        }

        if (prev == NULL) {
            newNode->next = mat->rows[row];
            mat->rows[row] = newNode;
        } else {
            prev->next = newNode;
            newNode->next = current;
        }
    }
}

void Display(SparseMatrix *mat) {

    for (int i = 0; i < mat->m; i++) {
        Node *current = mat->rows[i];
        for (int j = 0; j < mat->n; j++) {
            if (current && current->column == j) {
                printf("%d ", current->value);
                current = current->next;
            } else {
                printf("0 ");
            }
        }
        printf("\n");
    }
}