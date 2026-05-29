#ifndef STACK_H
#define STACK_H

#include <stdio.h>
#include <stdlib.h>

#include "Queue.h"

typedef struct {
    int size;
    int top;
    Node **arr;
} Stack;

void CreateStack(Stack **stack, int size) {

    *stack = (Stack *)malloc(sizeof(Stack));

    if (*stack == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }

    (*stack)->top = -1;
    (*stack)->size = size;

    (*stack)->arr =
        (Node **)malloc(size * sizeof(Node *));

    if ((*stack)->arr == NULL) {
        printf("Memory allocation failed\n");
        free(*stack);
        exit(1);
    }
}

void DisplayStack(Stack *stack) {

    if (stack == NULL) {
        return;
    }

    for (int i = stack->top; i >= 0; i--) {
        printf("%d ", stack->arr[i]->data);
    }

    printf("\n");
}

Node *Top(Stack *stack) {
    if (stack->top < 0) {
        return NULL;
    }

    return stack->arr[stack->top];
}

int isStackEmpty(Stack *stack) {
    return stack->top == -1;
}

int isStackFull(Stack *stack) {
    return stack->top == stack->size - 1;
}

int Push(Stack *stack, Node *node) {

    if (isStackFull(stack)) {
        return -1;
    }

    stack->arr[++stack->top] = node;

    return 0;
}

Node *Pop(Stack *stack) {

    if (isStackEmpty(stack)) {
        return NULL;
    }

    return stack->arr[stack->top--];
}

#endif