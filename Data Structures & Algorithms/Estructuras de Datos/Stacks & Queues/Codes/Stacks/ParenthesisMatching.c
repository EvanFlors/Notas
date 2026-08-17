#include <stdio.h>
#include <stdlib.h>

typedef struct {
    char *arr;
    int top;
    int capacity;
} Stack;

void Create(Stack **);

int Push(Stack **, char);
char Pop(Stack *);

int isBalance(char *);

int isEmpty(Stack *);
int isFull(Stack *);

int main() {

    Stack *stack = NULL;
    Create(&stack);

    if (isBalance("((a+b)*(c+d))")) {
        printf("Balanced\n");
    } else {
        printf("Not Balanced\n");
    }

    return 0;
}

void Create(Stack **stack) {
    *stack = (Stack *)malloc(sizeof(Stack));

    if (*stack == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }

    (*stack)->top = -1;
    (*stack)->capacity = 100; // Initial capacity
    (*stack)->arr = (char *)malloc((*stack)->capacity * sizeof(char));

    if ((*stack)->arr == NULL) {
        printf("Memory allocation failed\n");
        exit(1);
    }
}

int Push(Stack **stack, char value) {

    if (stack == NULL) {
        return -1; // Stack not initialized
    }

    if (isFull(*stack)) {
        return -1; // Stack overflow
    }

    (*stack)->arr[++(*stack)->top] = value;

    return 0;
}

char Pop(Stack *stack) {

    if (stack == NULL || isEmpty(stack)) {
        return '\0'; // Stack underflow
    }

    return stack->arr[stack->top--];
}

int isBalance(char *expression) {

    Stack *stack = NULL;
    Create(&stack);

    for (int i = 0; expression[i] != '\0'; i++) {
        char curr = expression[i];
        if (curr == '(' || curr == '{' || curr == '[') {
            Push(&stack, curr);
        } else if (curr == ')' || curr == '}' || curr == ']') {
            // Check for matching opening bracket
            if (isEmpty(stack)) {
                return 0; // Not balanced
            }
            char top = Pop(stack);
            if ((curr == ')' && top != '(') ||
                (curr == '}' && top != '{') ||
                (curr == ']' && top != '[')) {
                return 0; // Not balanced
            }
        }
    }

    int balanced = isEmpty(stack);
    free(stack->arr);
    free(stack);
    return balanced;
}

int isEmpty(Stack *stack) {
    return stack == NULL || stack->top == -1;
}

int isFull(Stack *stack) {
    return stack != NULL && stack->top == stack->capacity - 1;
}