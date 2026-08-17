#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void Create(int [], int, Node **);

void Display(Node *);
void DisplayRecursive(Node *);

void Insert(Node **, int, int);

int Delete(Node **, int);

int main() {

    Node *head;
    int A[] = {1, 2, 3, 4, 5};
    Create(A, 5, &head);
    Insert(&head, 2, 10);
    Delete(&head, 0);
    DisplayRecursive(head);

    return 0;
}

void Create(int A[], int n, Node **head) {

    if (!A) {
        return;
    }

    Node *t, *last;

    *head = (Node *)malloc(sizeof(Node));
    (*head)->data = A[0];
    (*head)->next = *head;

    last = *head;

    for (int i = 1; i < n; i++) {
        t = (Node *)malloc(sizeof(Node));
        t->data = A[i];
        t->next = last->next;

        last->next = t;
        last = t;
    }

}

void Display(Node *head) {
    if (!head) {
        return;
    }

    Node *current = head;
    do {
        printf("%d ", current->data);
        current = current->next;
    } while (current != head);

    printf("\n");
}

void DisplayRecursive(Node *h) {

    static Node *start = NULL;

    if (!h) return;

    if (!start) {
        start = h;
    }

    printf("%d ", h->data);

    if (h->next != start) {
        DisplayRecursive(h->next);
    } else {
        printf("\n");
        start = NULL; // Reset for future calls
    }
}

void Insert(Node **head, int pos, int x) {

    Node *p = *head, *t;

    if (pos < 0) {
        return;
    }

    if (pos == 0) {
        t = (Node *)malloc(sizeof(Node));
        t->data = x;

        if (!*head) {
            *head = t;
            t->next = t;
        } else {
            Node *last = *head;
            while (last->next != *head) {
                last = last->next;
            }
            last->next = t;
            t->next = *head;
            *head = t;
        }
    } else {
        for (int i = 0; i < pos - 1 && p->next != *head; i++) {
            p = p->next;
        }

        if (p->next == *head) {
            return; // Position out of bounds
        }

        t = (Node *)malloc(sizeof(Node));
        t->data = x;
        t->next = p->next;
        p->next = t;
    }

}

int Delete(Node **head, int pos) {

    int x;
    Node *p = *head, *q;

    if (!head || pos < 0) {
        return -1;
    }

    if (pos == 0) {

        while (p->next != *head) {
            p = p->next;
        }

        p->next = (*head)->next;
        x = (*head)->data;
        free(*head);
        *head = p->next;

    } else {

        for (int i = 0; i < pos - 2 && p->next != *head; i++) {
            p = p->next;
        }

        if (p->next == *head) {
            return -1; // Position out of bounds
        }

        q = p->next;
        p->next = q->next;
        x = q->data;
        free(q);
    }

    return x;
}