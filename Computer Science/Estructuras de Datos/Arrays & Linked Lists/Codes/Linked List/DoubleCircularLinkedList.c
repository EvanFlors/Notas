#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
    struct Node *prev;
} Node;

void Create(int [], int, Node **);
void Insert(Node **, int, int);
int Delete(Node **, int);
void Display(Node *);

int main() {

    int A[] = {1, 2, 3, 4, 5};
    Node *head;

    Create(A, 5, &head);
    Display(head);

    Insert(&head, 2, 10);
    Display(head);

    Delete(&head, 0);
    Display(head);

    return 0;
}

void Create(int A[], int n, Node **head) {

    if (n <= 0 || !A) {
        *head = NULL;
        return;
    }

    Node *t, *last;
    (*head) = (Node *)malloc(sizeof(Node));
    (*head)->data = A[0];
    (*head)->next = *head;
    (*head)->prev = *head;

    last = *head;
    for (int i = 1; i < n; i++) {
        t = (Node *)malloc(sizeof(Node));
        t->data = A[i];
        t->next = last->next;
        t->prev = last;

        last->next->prev = t;
        last->next = t;
        last = t;
    }

}


void Insert(Node **head, int position, int value) {
    if (position < 0) return;

    Node *newNode = (Node *)malloc(sizeof(Node));
    newNode->data = value;

    if (*head == NULL) {
        newNode->next = newNode;
        newNode->prev = newNode;
        *head = newNode;
        return;
    }

    Node *current = *head;
    for (int i = 0; i < position && current->next != *head; i++) {
        current = current->next;
    }

    newNode->next = current->next;
    newNode->prev = current;
    current->next->prev = newNode;
    current->next = newNode;
}


int Delete(Node **head, int position) {
    int x = -1;

    if (*head == NULL || position < 0) return x;

    Node *current = *head;
    for (int i = 0; i < position && current->next != *head; i++) {
        current = current->next;
    }

    if (current == *head) {
        if (current->next == *head) {
            x = current->data;
            free(current);
            *head = NULL;
        } else {
            x = current->data;
            current->prev->next = current->next;
            current->next->prev = current->prev;
            *head = current->next;
            free(current);
        }
    } else {
        x = current->data;
        current->prev->next = current->next;
        current->next->prev = current->prev;
        free(current);
    }

    return x;
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