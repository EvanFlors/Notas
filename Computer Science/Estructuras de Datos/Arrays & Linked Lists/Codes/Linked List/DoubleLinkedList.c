#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
    struct Node *prev;
} Node;

void Create(int [], int, Node **);
void Display(Node *);

void Insert(Node **, int, int);

int Delete(Node **, int);

void Reverse(Node **);
void ReverseRecursive(Node **, Node *, Node *);

int Length(Node *);


int main() {

    int A[] = {1, 2, 3, 4, 5};
    Node *head;

    Create(A, 5, &head);
    ReverseRecursive(&head, head, NULL);
    Display(head);

    return 0;
}


void Create(int A[], int n, Node **head) {

    if (n <= 0 || !A) {
        *head = NULL;
        return;
    }

    Node *t, *last;
    *head = (Node *)malloc(sizeof(Node));
    (*head)->data = A[0];
    (*head)->next = NULL;
    (*head)->prev = NULL;

    last = *head;

    for (int i = 1; i < n; i++) {
        t = (Node *)malloc(sizeof(Node));
        t->data = A[i];
        t->next = NULL;
        t->prev = last;

        last->next = t;
        last = t;
    }

}


void Insert(Node **head, int pos, int x) {

    Node *t;

    if (pos == 0) {
        t = (Node *)malloc(sizeof(Node));
        t->data = x;
        t->next = *head;
        t->prev = NULL;

        if (*head) {
            (*head)->prev = t;
        }

        *head = t;
    } else {
        Node *current = *head;
        for (int i = 0; i < pos - 1 && current != NULL; i++) {
            current = current->next;
        }

        if (current != NULL) {
            t = (Node *)malloc(sizeof(Node));
            t->data = x;
            t->next = current->next;
            t->prev = current;

            if (current->next != NULL) {
                current->next->prev = t;
            }

            current->next = t;
        }
    }

}


int Delete(Node **head, int pos) {

    int x = -1;
    Node *p = *head;

    if (*head == NULL || pos < 0) {
        return x;
    }

    if (pos == 0) {

        *head = (*head)->next;
        x = p->data;

        free(p);

        if (*head) {
            (*head)->prev = NULL;
        }
    } else {

        Node *q = NULL;

        for (int i = 0; i < pos && p != NULL; i++) {
            q = p;
            p = p->next;
        }

        if (p != NULL) {
            q->next = p->next;
            x = p->data;

            if (p->next != NULL) {
                p->next->prev = q;
            }

            free(p);
        }

    }

    return x;
}


void Display(Node *p) {
    while (p->next != NULL) {
        printf("%d ", p->data);
        p = p->next;
    }

    printf("\n");
}


void Reverse(Node **head) {

    Node *p = *head, *tmp;

    while(p != NULL) {

        tmp = p->next;
        p->next = p->prev;
        p->prev = tmp;
        p = tmp;

        if (p->next == NULL) {
            *head = p;
        }

    }

}


void ReverseRecursive(Node **head, Node *p, Node *q) {

    if (p == NULL) {
        *head = q;
        return;
    }

    ReverseRecursive(head, p->next, p);
    p->next = p->prev;
    p->prev = q;

}


int Length(Node *p) {
    int count = 0;
    while (p != NULL) {
        count++;
        p = p->next;
    }
    return count;
}
