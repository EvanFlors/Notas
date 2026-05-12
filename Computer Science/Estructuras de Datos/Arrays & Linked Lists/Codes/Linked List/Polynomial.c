#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef struct Node {
    int coefficient;
    int exponent;
    struct Node *next;
} Node;

void Create(Node **);
void Display(Node *);
double Evaluate(Node *, double);

int main() {
    Node *poly = NULL;
    double x;

    Create(&poly);
    Display(poly);

    printf("Enter a value for x: ");
    scanf("%lf", &x);
    printf("Polynomial evaluated at x = %lf is %lf\n", x, Evaluate(poly, x));

    return 0;
}

void Create(Node **head) {

    Node *t, *last;

    t = (Node *)malloc(sizeof(Node));

    if (t == NULL) {
        printf("Memory allocation failed\n");
        return;
    }

    while (1) {
        printf("Enter coefficient and exponent (or -1 -1 to stop): ");
        scanf("%d %d", &t->coefficient, &t->exponent);

        if (t->coefficient == -1 && t->exponent == -1) {
            free(t);
            break;
        }

        t->next = NULL;

        if (*head == NULL) {
            *head = last = t;
        } else {
            last->next = t;
            last = t;
        }

        t = (Node *)malloc(sizeof(Node));

        if (t == NULL) {
            printf("Memory allocation failed\n");
            return;
        }
    }

}


void Display(Node *head) {

    Node *t = head;

    while (t != NULL) {
        printf("%dx^%d ", t->coefficient, t->exponent);
        t = t->next;
    }

}


double Evaluate(Node *head, double x) {

    double result = 0.0;
    Node *t = head;

    while (t != NULL) {
        result += t->coefficient * pow(x, t->exponent);
        t = t->next;
    }

    return result;
}