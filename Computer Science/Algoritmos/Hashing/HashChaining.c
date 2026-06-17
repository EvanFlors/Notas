#include <stdio.h>
#include <stdlib.h>

#define SIZE 10

typedef struct Node {
    int value;
    struct Node *next;
} Node;

void HashChaining(int A[], int n, Node **arr);

void InsertNode(Node **arr, int index, int value);

Node *SearchNode(Node **arr, int value);

int DeleteNode(Node **arr, int value);

Node *CreateNode(int value);
Node **CreateArrayNodes(int size);

int main() {

    int A[] = {5, 12, 32, 45, 56, 49, 11, 47, 82, 14, 8, 38, 57, 18, 89, 101, 301};
    int n = sizeof(A) / sizeof(A[0]);

    Node **arr = CreateArrayNodes(SIZE);

    HashChaining(A, n, arr);

    DeleteNode(arr, 11);

    for(int i = 0; i < SIZE; i++) {
        printf("[%d] ", i);
        Node *current = arr[i];
        while(current != NULL) {
            printf("[%d]", current->value);
            if (current->next != NULL) {
                printf(" -> ");
            }
            current = current->next;
        }
        printf("\n");
    }

    return 0;
}

void HashChaining(int A[], int n, Node **arr) {
    for (int i = 0; i < n; i++) {
        int index = A[i] % SIZE;
        InsertNode(arr, index, A[i]);
    }
}

void InsertNode(Node **arr, int index, int value)
{
    Node *new_node = CreateNode(value);
    Node *current = arr[index];
    Node *prev = NULL;

    while (current != NULL && value > current->value) {
        prev = current;
        current = current->next;
    }

    new_node->next = current;

    if (prev == NULL)
        arr[index] = new_node;
    else
        prev->next = new_node;
}

Node *SearchNode(Node **arr, int value) {
    int index = value % SIZE;
    Node *current = arr[index];

    while (current != NULL) {
        if (current->value == value) {
            return current;
        }
        current = current->next;
    }

    return NULL;
}

int DeleteNode(Node **arr, int value) {
    int index = value % SIZE;
    Node *current = arr[index];
    Node *prev = NULL;

    while (current != NULL) {
        if (current->value == value) {
            if (prev == NULL) {
                arr[index] = current->next;
            } else {
                prev->next = current->next;
            }
            return current->value;
            free(current);
        }
        prev = current;
        current = current->next;
    }

    return -1;
}

Node **CreateArrayNodes(int size) {

    Node **arr = (Node **)malloc(sizeof(Node *) * size);

    for (int i = 0; i < size; i++) {
        arr[i] = NULL;
    }

    return arr;
}

Node *CreateNode(int value) {

    Node *node = (Node *)malloc(sizeof(Node));

    node->value = value;
    node->next = NULL;

    return node;
}