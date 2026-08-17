#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int front;
    int rear;
    int size;
} Deque;

void Create(Deque **, int);
void Display(Deque *);

void EnqueueFront(Deque *, int);
int DequeueFront(Deque *);

void EnqueueRear(Deque *, int);
int DequeueRear(Deque *);

int IsEmpty(Deque *);
int IsFull(Deque *);

void Destroy(Deque *);

int main() {

    Deque *q;
    Create(&q, 5);

    EnqueueFront(q, 10);
    EnqueueFront(q, 20);

    EnqueueRear(q, 30);
    EnqueueRear(q, 40);

    printf("Dequeued from front: %d\n", DequeueFront(q));

    Display(q);

    Destroy(q);
    return 0;
}

void Create(Deque **q, int size) {

    *q = (Deque *)malloc(sizeof(Deque));
    (*q)->data = (int *)malloc(size * sizeof(int));
    (*q)->front = -1;
    (*q)->rear = -1;
    (*q)->size = size;

}

void Display(Deque *q) {

    if (q == NULL || IsEmpty(q)) {
        printf("Deque is empty.\n");
        return;
    }

    printf("Deque elements: ");
    for (int i = q->front; i <= q->rear; i++) {
        printf("%d ", q->data[i]);
    }
    printf("\n");
}

void Destroy(Deque *q) {
    if (q) {
        free(q->data);
        free(q);
    }
}

int IsEmpty(Deque *q) {
    return q->front == -1;
}

int IsFull(Deque *q) {
    return (q->rear == q->size - 1 && q->front == 0) || (q->front > 0 && q->front - 1 == q->rear);
}

void EnqueueFront(Deque *q, int value) {

    if (q->front == 0 || IsFull(q)) {
        printf("Cannot insert at front\n");
        return;
    }

    if (q->front == -1) {
        // Empty deque: place at index 0
        q->front = 0;
        q->rear = 0;
    } else {
        q->front--;
    }
    q->data[q->front] = value;
}

void EnqueueRear(Deque *q, int value) {

    if (q->rear == q->size - 1 || IsFull(q)) {
        printf("Cannot insert at rear\n");
        return;
    }

    if (q->front == -1) {
        q->front = 0;
        q->rear = 0;
    } else {
        q->rear++;
    }
    q->data[q->rear] = value;
}

int DequeueFront(Deque *q) {

    if (IsEmpty(q)) {
        printf("Deque is empty\n");
        return -1;
    }

    int x = q->data[q->front];

    if (q->front == q->rear) {
        q->front = q->rear = -1;
    } else {
        q->front++;
    }

    return x;
}

int DequeueRear(Deque *q) {

    if (IsEmpty(q)) {
        printf("Deque is empty\n");
        return -1;
    }

    int x = q->data[q->rear];

    if (q->front == q->rear) {
        q->front = q->rear = -1;
    } else {
        q->rear--;
    }

    return x;
}