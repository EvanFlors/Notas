#include <stdio.h>
#include <stdlib.h>

#define MAX_PRIORITY 10
#define QUEUE_SIZE 100

typedef struct {
    int *data;
    int front;
    int rear;
    int size;
    int capacity;
} Queue;

typedef struct {
    Queue queues[MAX_PRIORITY];
    int levels;
} PriorityQueue;

void Create(PriorityQueue **);
void Destroy(PriorityQueue *);
void Display(PriorityQueue *);

void Enqueue(PriorityQueue *, int, int);
int Dequeue(PriorityQueue *);

int main() {

    PriorityQueue *queue;
    Create(&queue);

    Enqueue(queue, 10, 0);
    Enqueue(queue, 20, 0);
    Enqueue(queue, 30, 0);
    Enqueue(queue, 40, 0);
    Enqueue(queue, 50, 0);

    Enqueue(queue, 60, 1);
    Enqueue(queue, 70, 1);
    Enqueue(queue, 80, 1);
    Enqueue(queue, 90, 1);
    Enqueue(queue, 100, 1);

    for (int i = 0; i < 10; i++) {
        int value = Dequeue(queue);
        if (value != -1) {
            printf("Dequeued: %d\n", value);
        }
    }

    Destroy(queue);

    return 0;
}

void Create(PriorityQueue **pq) {
    *pq = (PriorityQueue *)malloc(sizeof(PriorityQueue));
    if (*pq) {
        for (int i = 0; i < MAX_PRIORITY; i++) {
            (*pq)->queues[i].data = (int *)malloc(QUEUE_SIZE * sizeof(int));
            (*pq)->queues[i].front = -1;
            (*pq)->queues[i].rear = -1;
            (*pq)->queues[i].size = 0;
            (*pq)->queues[i].capacity = QUEUE_SIZE;
        }
        (*pq)->levels = MAX_PRIORITY;
    }
}

void Destroy(PriorityQueue *pq) {
    if (pq) {
        for (int i = 0; i < MAX_PRIORITY; i++) {
            free(pq->queues[i].data);
        }
        free(pq);
    }
}

void Display(PriorityQueue *pq) {

    if (!pq) {
        return;
    }

    for (int i = 0; i < pq->levels; i++) {
        printf("Priority %d: ", i);
        Queue *q = &pq->queues[i];
        for (int j = q->front; j != q->rear; j = (j + 1) % q->capacity) {
            printf("%d ", q->data[j]);
        }
        printf("\n");
    }
}

void Enqueue(PriorityQueue *pq, int value, int priority) {
    if (priority < 0 || priority >= pq->levels) {
        printf("Invalid priority level\n");
        return;
    }

    Queue *q = &pq->queues[priority];
    if (q->size == q->capacity) {
        printf("Queue at priority %d is full\n", priority);
        return;
    }

    if (q->front == -1) {
        q->front = 0;
    }

    q->rear = (q->rear + 1) % q->capacity;
    q->data[q->rear] = value;
    q->size++;
}

int Dequeue(PriorityQueue *pq) {

    int x = -1;

    if (!pq) {
        printf("Priority Queue not initialized\n");
        return x;
    }

    for (int i = 0; i < pq->levels; i++) {
        Queue *q = &pq->queues[i];
        if (q->size > 0) {
            x = q->data[q->front];
            q->front = (q->front + 1) % q->capacity;
            q->size--;
            break;
        }
    }

    return x;
}