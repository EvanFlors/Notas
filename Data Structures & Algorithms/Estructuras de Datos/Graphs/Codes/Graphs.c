#include <stdio.h>
#include <stdlib.h>
#include "Queue.h"

#define SIZE 7

void BFS(int A[SIZE][SIZE], int start);
void DFS(int A[SIZE][SIZE], int start);

int main() {

    int A[SIZE][SIZE] = {
        {0, 0, 0, 0, 0, 0, 0},
        {0, 0, 1, 1, 0, 0, 0},
        {0, 1, 0, 0, 1, 0, 0},
        {0, 1, 0, 0, 1, 0, 0},
        {0, 0, 1, 1, 0, 1, 1},
        {0, 0, 0, 0, 1, 0, 0},
        {0, 0, 0, 0, 1, 0, 0}
    };

    BFS(A, 1);
    printf("\n");

    DFS(A, 1);
    printf("\n");

    return 0;
}

void BFS(int A[SIZE][SIZE], int start) {

    int i = start;
    Queue *queue = CreateQueue(7);
    int visited[SIZE] = {0};

    visited[i] = 1;
    enqueue(queue, i);
    printf("%d ", i);

    while (!isEmpty(queue)) {
        i = dequeue(queue);

        for (int j = 0; j < SIZE; j++) {
            if (A[i][j] == 1 && !visited[j]) {
                printf("%d ", j);
                visited[j] = 1;
                enqueue(queue, j);
            }
        }
    }

    DestroyQueue(queue);
}

void DFS(int A[SIZE][SIZE], int start) {

    static int visited[SIZE] = {0};

    printf("%d ", start);
    visited[start] = 1;

    for (int j = 0; j < SIZE; j++) {
        if (A[start][j] == 1 && !visited[j]) {
            DFS(A, j);
        }
    }
}