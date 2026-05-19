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
    enqueue(queue, 40);
    enqueue(queue, 50);
    enqueue(queue, 60);

    printf("Dequeued: %d\n", dequeue(queue));
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
    if (isFull(q)) {
        printf("Queue is full\n");
        return;
    }
    if (q->front == -1) {
        q->front = 0;
    }
    q->rear = (q->rear + 1) % q->size;
    q->data[q->rear] = value;
}

int dequeue(Queue *q) {
    if (isEmpty(q)) {
        printf("Queue is empty\n");
        return -1;
    }
    int x = q->data[q->front];
    if (q->front == q->rear) {
        // Last element: reset queue
        q->front = -1;
        q->rear = -1;
    } else {
        q->front = (q->front + 1) % q->size;
    }
    return x;
}

int isEmpty(Queue *q) {
    return q->front == -1;
}

int isFull(Queue *q) {
    return (q->rear + 1) % q->size == q->front;
}