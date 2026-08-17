#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void BucketSort(int A[], int n);
void InsertNode(Node **head, int value);
Node *CreateNode(int value);
Node **CreateBucket(int n);

int FindMax(int A[], int n);

int main() {

    int A[] = {4, 5, 1, 6, 7, 2, 1, 7, 8, 2, 3, 6, 9, 2, 3};
    int n = sizeof(A) / sizeof(A[0]);

    BucketSort(A, n);

    for (int i = 0; i < n; i++) {
        printf("%d ", A[i]);
    }
    printf("\n");

    return 0;
}

void BucketSort(int A[], int n) {
    int i, j;
    int max = FindMax(A, n);
    Node **buckets = CreateBucket(max + 1);

    for (i = 0; i < n; i++) {
        InsertNode(buckets, A[i]);
    }

    i = j = 0;
    while (i < max + 1) {
        Node *current = buckets[i];
        while (current != NULL) {
            A[j++] = current->data;
            current = current->next;
        }
        i++;
    }
}

void InsertNode(Node **bucket, int index) {
    Node *newNode = CreateNode(index);

    if (bucket[index] == NULL) {
        bucket[index] = newNode;
    } else {
        Node *current = bucket[index];
        newNode->next = current;
        bucket[index] = newNode;
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