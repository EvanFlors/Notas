#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

typedef struct {
    Node *top;

} Stack;

void Create(Stack **);
void Display(Stack *);

int Push(Stack **, int);
int Pop(Stack *);
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

    Display(s);

    return 0;
}

void Create(Stack **stack) {

    *stack = (Stack *)malloc(sizeof(Stack));

    if (stack == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }

    (*stack)->top = NULL;

}

void Display(Stack *stack) {

    if (stack == NULL) {
        return;
    }

    while (stack->top != NULL) {
        printf("%d ", stack->top->data);
        stack->top = stack->top->next;
    }

    printf("\n");
}

int Push(Stack **stack, int value) {

    if (stack == NULL) {
        return -1; // Stack not initialized
    }

    Node *newNode = (Node *)malloc(sizeof(Node));
    if (newNode == NULL) {
        return -1; // Memory allocation failed
    }

    newNode->data = value;
    newNode->next = (*stack)->top;
    (*stack)->top = newNode;

    return 0;
}

int Pop(Stack *stack) {

    if (isEmpty(stack)) {
        return -1; // Stack underflow
    }

    Node *temp = stack->top;
    int poppedValue = temp->data;
    stack->top = stack->top->next;
    free(temp);

    return poppedValue;
}

int StackTop(Stack *stack) {
    if (isEmpty(stack)) {
        return -1; // Stack is empty
    }

    return stack->top->data;
}

int isEmpty(Stack *stack) {
    if (stack == NULL) {
        return 1; // Stack not initialized, consider it empty
    }

    return stack->top == NULL;
}

int isFull(Stack *stack) {
    Node *newNode = (Node *)malloc(sizeof(Node));
    if (newNode == NULL) {
        return 1; // Stack is full
    }
    free(newNode);
    return 0;
}