#ifndef QUEUE_H
#define QUEUE_H

#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int front;
    int rear;
    int count;
    int capacity;
    int *data;
} Queue;

static inline Queue *CreateQueue(int capacity)
{
    Queue *q = malloc(sizeof(*q));

    if (q == NULL) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }

    q->front = 0;
    q->rear = 0;
    q->count = 0;
    q->capacity = capacity;

    q->data = malloc(capacity * sizeof(*q->data));

    if (q->data == NULL) {
        free(q);
        perror("malloc");
        exit(EXIT_FAILURE);
    }

    return q;
}

static inline void DestroyQueue(Queue *q)
{
    if (q == NULL)
        return;

    free(q->data);
    free(q);
}

static inline int isEmpty(const Queue *q)
{
    return q->count == 0;
}

static inline int isFull(const Queue *q)
{
    return q->count == q->capacity;
}

static inline int Size(const Queue *q)
{
    return q->count;
}

static inline void enqueue(Queue *q, int value)
{
    if (isFull(q)) {
        fprintf(stderr, "Queue overflow\n");
        return;
    }

    q->data[q->rear] = value;
    q->rear = (q->rear + 1) % q->capacity;
    q->count++;
}

static inline int dequeue(Queue *q)
{
    if (isEmpty(q)) {
        fprintf(stderr, "Queue underflow\n");
        return -1;
    }

    int value = q->data[q->front];

    q->front = (q->front + 1) % q->capacity;
    q->count--;

    return value;
}

static inline int Front(const Queue *q)
{
    if (isEmpty(q)) {
        fprintf(stderr, "Queue is empty\n");
        return -1;
    }

    return q->data[q->front];
}

static inline int Rear(const Queue *q)
{
    if (isEmpty(q)) {
        fprintf(stderr, "Queue is empty\n");
        return -1;
    }

    int index = (q->rear - 1 + q->capacity) % q->capacity;
    return q->data[index];
}

static inline void PrintQueue(const Queue *q)
{
    if (isEmpty(q)) {
        printf("Queue is empty\n");
        return;
    }

    printf("Front -> ");

    for (int i = 0; i < q->count; i++) {
        int index = (q->front + i) % q->capacity;
        printf("%d ", q->data[index]);
    }

    printf("<- Rear\n");
}

#endif