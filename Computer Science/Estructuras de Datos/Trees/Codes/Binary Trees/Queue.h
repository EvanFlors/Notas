#ifndef QUEUE_H
#define QUEUE_H

#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *left;
    struct Node *right;
} Node;

typedef struct {
    int front;
    int rear;
    int size;
    Node **queue;
} Queue;

void CreateQueue(Queue **q, int size) {
    *q = (Queue *)malloc(sizeof(Queue));
    (*q)->front = (*q)->rear = 0;
    (*q)->size = size;

    (*q)->queue = (Node **)malloc(size * sizeof(Node *));
}

void DestroyQueue(Queue *q) {
    if (q) {
        free(q->queue);
        free(q);
    }
}

int isEmpty(Queue *q) {
    if (q) return q->front == q->rear;
    return 1;
}

int isFull(Queue *q) {
    if (q) return (q->rear + 1) % q->size == q->front;
    return 0;
}

void enqueue(Queue *q, Node *node) {
    if (q && !isFull(q)) {
        q->rear = (q->rear + 1) % q->size;
        q->queue[q->rear] = node;
    }
}

Node *dequeue(Queue *q) {

    Node *tmp = NULL;

    if (q && !isEmpty(q)) {
        q->front = (q->front + 1) % q->size;
        tmp = q->queue[q->front];
    }
    return tmp;
}

#endif
