#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

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

int outStackPrecedence(char);
int inStackPrecedence(char);

int isOperator(char);
char *infixToPostfix(char *);

int Evaluate(char *);

int main() {

    char infix[] = "3*5+6/2-4";
    char *postfix = infixToPostfix(infix);

    int result = Evaluate(postfix);
    printf("Result: %d\n", result);

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

int outStackPrecedence(char c) {
    switch (c) {
        case '+':
        case '-':
            return 1;
        case '*':
        case '/':
            return 3;
        case '^':
            return 6;
        case '(':
            return 7;
        case ')':
            return 0;
        default:
            return -1; // For non-operators
    }
}

int inStackPrecedence(char c) {
    switch (c) {
        case '+':
        case '-':
            return 2;
        case '*':
        case '/':
            return 4;
        case '^':
            return 5;
        case '(':
            return 0;
        default:
            return -1; // For non-operators
    }
}

int isOperator(char c) {
    return (c == '+' || c == '-' || c == '*' || c == '/' || c == '^' || c == '(' || c == ')');
}

char *infixToPostfix(char *infix) {

    Stack *stack;
    int length = strlen(infix);

    Create(&stack, length);
    char *postfix = (char *)malloc((length + 1) * sizeof(char));

    int i = 0, j = 0;

    while (infix[i] != '\0') {
        if (!isOperator(infix[i])) {
            postfix[j++] = infix[i++];
        } else if (infix[i] == ')') {
            while (!isEmpty(stack) && stack->arr[stack->top] != '(') {
                postfix[j++] = Pop(stack);
            }
            Pop(stack); // Pop the '('
            i++;
        } else {
            while (!isEmpty(stack) && outStackPrecedence(infix[i]) <= inStackPrecedence(stack->arr[stack->top])) {
                postfix[j++] = Pop(stack);
            }
            Push(stack, infix[i++]);
        }
    }

    while (!isEmpty(stack)) {
        postfix[j++] = Pop(stack);
    }
    postfix[j] = '\0';
    return postfix;
}

int Evaluate(char *postfix) {

    Stack *stack;
    int length = strlen(postfix);
    Create(&stack, length);

    for(int i = 0; i < length; i++) {
        if (postfix[i] >= '0' && postfix[i] <= '9') {
            Push(stack, postfix[i] - '0');
        } else {
            int op2 = Pop(stack);
            int op1 = Pop(stack);
            switch (postfix[i]) {
                case '+': Push(stack, op1 + op2); break;
                case '-': Push(stack, op1 - op2); break;
                case '*': Push(stack, op1 * op2); break;
                case '/': Push(stack, op1 / op2); break;
                case '^': Push(stack, (int)pow(op1, op2)); break;
            }
        }
    }

    int result = Pop(stack);

    free(stack->arr);
    free(stack);

    return result;
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