#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

typedef struct {
    Node *front;
    Node *rear;
} Queue;

void Create(Queue **);
void Destroy(Queue *);

void enqueue(Queue *, int);
int dequeue(Queue *);

int isEmpty(Queue *);
int isFull(Queue *);

int main() {

    Queue *q;
    Create(&q);

    enqueue(q, 10);
    enqueue(q, 20);
    enqueue(q, 30);

    printf("Dequeued: %d\n", dequeue(q));
    printf("Dequeued: %d\n", dequeue(q));
    printf("Dequeued: %d\n", dequeue(q));
    printf("Dequeued: %d\n", dequeue(q));

    Destroy(q);

    return 0;
}

void enqueue(Queue *q, int value) {
    if (isFull(q)) {
        printf("Queue is full\n");
        return;
    }

    Node *newNode = (Node *)malloc(sizeof(Node));
    newNode->data = value;
    newNode->next = NULL;

    if (isEmpty(q)) {
        q->front = q->rear = newNode;
    } else {
        q->rear->next = newNode;
    }
    q->rear = newNode;
}

int dequeue(Queue *q) {

    int x = -1;
    Node *p;

    if (q->front == NULL) {
        printf("Queue is empty\n");
    } else {
        p = q->front;
        x = p->data;
        q->front = q->front->next;
        free(p);
    }

    if (q->front == NULL) {
        q->rear = NULL;
    }

    return x;
}

void Create(Queue **q) {
    *q = (Queue *)malloc(sizeof(Queue));
    (*q)->front = NULL;
    (*q)->rear = NULL;
}

void Destroy(Queue *q) {
    while (!isEmpty(q)) {
        dequeue(q);
    }
    free(q);
}

int isFull(Queue *q) {

    Node *newNode = (Node *)malloc(sizeof(Node));
    if (newNode == NULL) {
        return 1;  // Queue is full
    }
    free(newNode);
    return 0;  // Queue is not full
}

int isEmpty(Queue *q) {
    return q->front == NULL;
}