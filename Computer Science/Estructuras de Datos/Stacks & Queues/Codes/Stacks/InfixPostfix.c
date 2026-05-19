#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char *arr;
    int top;
    int capacity;
} Stack;

void Create(Stack **, int);
void Display(Stack *);

int Push(Stack *, char);
char Pop(Stack *);

int isEmpty(Stack *);
int isFull(Stack *);

int precedence(char);
int isOperator(char);
void infixToPostfix(char *);

int main() {

    char infix[] = "a+b*c-d/e";
    infixToPostfix(infix);

    return 0;
}

void Create(Stack **stack, int capacity) {
    *stack = (Stack *)malloc(sizeof(Stack));
    (*stack)->capacity = capacity;
    (*stack)->top = -1;
    (*stack)->arr = (char *)malloc((*stack)->capacity * sizeof(char));
}

void Display(Stack *stack) {
    for (int i = stack->top; i >= 0; i--) {
        printf("%c ", stack->arr[i]);
    }
    printf("\n");
}

int precedence(char c) {
    switch (c) {
        case '+':
        case '-':
            return 1;
        case '*':
        case '/':
            return 2;
        default:
            return 0; // For non-operators
    }
}

int isOperator(char c) {
    return (c == '+' || c == '-' || c == '*' || c == '/');
}

void infixToPostfix(char *infix) {

    Stack *stack;
    int length = strlen(infix);

    Create(&stack, length);
    char postfix[length + 1];

    int i = 0, j = 0;

    while (infix[i] != '\0') {
        if (!isOperator(infix[i])) {
            postfix[j++] = infix[i++];
        } else {
            if (precedence(infix[i]) > precedence(stack->arr[stack->top])) {
                Push(stack, infix[i++]);
            } else {
                postfix[j++] = Pop(stack);
            }
        }
    }

    while (!isEmpty(stack)) {
        postfix[j++] = Pop(stack);
    }
    postfix[j] = '\0';

    printf("Postfix: %s\n", postfix);
}

int Push(Stack *stack, char value) {
    if (isFull(stack)) {
        return -1; // Stack overflow
    }
    stack->arr[++stack->top] = value;
    return 0;
}

char Pop(Stack *stack) {
    if (isEmpty(stack)) {
        return '\0'; // Stack underflow
    }
    return stack->arr[stack->top--];
}

int isEmpty(Stack *stack) {
    return stack->top == -1;
}

int isFull(Stack *stack) {
    return stack->top == stack->capacity - 1;
}