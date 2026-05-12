#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int size;
    int top;
    int *arr;
} Stack;

void Create(Stack **);
void Display(Stack *);

int Push(Stack **, int);
int Pop(Stack *);
int Peek(Stack *, int);
int StackTop(Stack *);
int isEmpty(Stack *);
int isFull(Stack *);

int main() {

    Stack *s;
    Create(&s);

    Push(&s, 1);
    Push(&s, 2);
    Push(&s, 3);
    Push(&s, 4);

    return 0;
}

void Create(Stack **stack) {

    *stack = (Stack *)malloc(sizeof(Stack));

    if (stack == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }

    printf("Size of stack: ");
    scanf("%d", &(*stack)->size);
    (*stack)->top = -1;

    (*stack)->arr = (int *)malloc((*stack)->size * sizeof(int));

    if ((*stack)->arr == NULL) {
        printf("Memory allocation failed\n");
        free(*stack);
        exit(1);
    }

}

void Display(Stack *stack) {

    if (stack == NULL) {
        return;
    }

    for (int i = stack->top; i >= 0; i--) {
        printf("%d ", stack->arr[i]);
    }

    printf("\n");

}

int Push(Stack **stack, int value) {

    if (isFull(*stack)) {
        return -1; // Stack overflow
    }

    int top = ++(*stack)->top;
    (*stack)->arr[top] = value;

    return 0;

}

int Pop(Stack *stack) {

    if (isEmpty(stack)) {
        return -1; // Stack underflow
    }

    return stack->arr[stack->top--];
}

int Peek(Stack *stack, int index) {

    if (isEmpty(stack)) {
        return -1; // Stack is empty
    }

    if (index < 0 || index > stack->top) {
        return -1; // Invalid index
    }

    return stack->arr[stack->top - (stack->top - index)];

}

int StackTop(Stack *stack) {

    if (isEmpty(stack)) {
        return -1; // Stack is empty
    }

    return stack->arr[stack->top];
}

int isEmpty(Stack *stack) {

    return stack->top == -1;

}

int isFull(Stack *stack) {
    return stack->top == stack->size - 1;
}