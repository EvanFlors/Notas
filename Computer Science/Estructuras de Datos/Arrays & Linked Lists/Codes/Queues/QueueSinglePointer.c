#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int *data;
    int front;
    int rear;
    int size;
} Queue;

void Create(Queue **, int);
void Destroy(Queue *);

void enqueue(Queue *, int);
int dequeue(Queue *);
int isEmpty(Queue *);
int isFull(Queue *);
int first(Queue *);
int last(Queue *);

int main() {

    Queue *queue;
    Create(&queue, 5);

    enqueue(queue, 10);
    enqueue(queue, 20);
    enqueue(queue, 30);

    printf("Dequeued: %d\n", dequeue(queue));
    printf("Dequeued: %d\n", dequeue(queue));

    Destroy(queue);

    return 0;
}

void Create(Queue **q, int size) {

    *q = (Queue *)malloc(sizeof(Queue));

    (*q)->data = (int *)malloc(size * sizeof(int));
    (*q)->front = -1;
    (*q)->rear = -1;
    (*q)->size = size;

}

void Destroy(Queue *q) {
    if (q) {
        free(q->data);
        free(q);
    }
}

void enqueue(Queue *q, int value) {
    if (q && !isFull(q)) {
        q->data[q->rear++] = value;
        if (q->front == -1) {
            q->front = 0;
        }
    }
}

int dequeue(Queue *q) {
    if (q && !isEmpty(q)) {
        int value = q->data[q->front++];
        if (q->front > q->rear) {
            q->front = q->rear = -1; // Reset queue when empty
        }
        return value;
    }
    return -1; // Queue underflow or not initialized
}

int isEmpty(Queue *q) {
    if (q) {
        return q->front == -1;
    }
    return 1;
}

int isFull(Queue *q) {
    if (q) {
        return ((q->rear + 1) == (q->size - 1));
    }
    return 0;
}