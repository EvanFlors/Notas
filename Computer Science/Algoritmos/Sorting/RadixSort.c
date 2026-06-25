#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void RadixSort(int A[], int n);
void CountingSort(int A[], int n, int exp);

void InsertNode(Node **head, int index, int value);
Node *CreateNode(int value);
Node **CreateBucket(int n);

int FindMax(int A[], int n);

int main() {

    int A[] = {90, 237, 438, 8, 129, 304, 531, 329, 839, 910, 629, 48};
    int n = sizeof(A) / sizeof(A[0]);

    RadixSort(A, n);

    for (int i = 0; i < n; i++) {
        printf("%d ", A[i]);
    }
    printf("\n");

    return 0;
}

void RadixSort(int A[], int n) {

    int max = FindMax(A, n);
    for (int exp = 1; max / exp > 0; exp *= 10) {
        // printf("Sorting by digit at place %d\n", exp);
        CountingSort(A, n, exp);
    }
}

void CountingSort(int A[], int n, int exp) {
    Node **buckets = CreateBucket(10);

    for (int i = 0; i < n; i++) {
        int index = (A[i] / exp) % 10;
        InsertNode(buckets, index, A[i]);
    }

    int idx = 0;
    for (int i = 0; i < 10; i++) {
        Node *current = buckets[i];
        while (current != NULL) {
            A[idx++] = current->data;
            current = current->next;
        }
    }

    // Free memory
    for (int i = 0; i < 10; i++) {
        Node *current = buckets[i];
        while (current != NULL) {
            Node *temp = current;
            current = current->next;
            free(temp);
        }
    }
    free(buckets);
}

void InsertNode(Node **bucket, int index, int value) {
    Node *newNode = CreateNode(value);

    if (bucket[index] == NULL) {
        bucket[index] = newNode;
    } else {
        Node *current = bucket[index];
        while (current->next != NULL) {
            current = current->next;
        }
        current->next = newNode;
    }
}

Node **CreateBucket(int n) {
    Node **buckets = (Node **)malloc(n * sizeof(Node *));
    for (int i = 0; i < n; i++) {
        buckets[i] = NULL;
    }
    return buckets;
}

Node *CreateNode(int value) {
    Node *p = (Node *)malloc(sizeof(Node));

    if (p == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }

    p->data = value;
    p->next = NULL;

    return p;
}

int FindMax(int A[], int n) {
    int max = A[0];
    for (int i = 1; i < n; i++) {
        if (A[i] > max) {
            max = A[i];
        }
    }
    return max;
}