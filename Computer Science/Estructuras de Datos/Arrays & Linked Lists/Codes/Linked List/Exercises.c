#include <stdio.h>
#include <stdlib.h>

#define MAX 100

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void Create(int [], int, Node **);
void Display(Node *);

int FindMiddleElement(Node *);
int FindIntersection(Node *, Node *);

int main() {

    int A[] = {1, 2, 3, 4, 5};
    int B[] = {6, 7, 8};

    Node *headA = NULL;
    Node *headB = NULL;

    Create(A, sizeof(A) / sizeof(A[0]), &headA);
    Display(headA);

    Create(B, sizeof(B) / sizeof(B[0]), &headB);

    // Walk to node with value 3 in list A (index 2)
    Node *intersection = headA;
    for (int i = 0; i < 2; i++) {
        intersection = intersection->next;
    }

    // Walk to the last node in list B
    Node *tail = headB;
    while (tail->next != NULL) {
        tail = tail->next;
    }

    tail->next = intersection;  // Creating an intersection at node with value 3

    Display(headB);

    int intersect = FindIntersection(headA, headB);
    printf("Intersection at node with value: %d\n", intersect);

    return 0;
}

int FindMiddleElement(Node *head) {

    if (head == NULL) {
        return -1;  // Meaningful value indicating empty list
    }

    Node *slow = head;
    Node *fast = head;

    while (fast != NULL && fast->next != NULL) {
        slow = slow->next;
        fast = fast->next->next;
    }

    return slow->data;

}

int FindIntersection(Node *A, Node *B) {

    if (!A || !B) return -1;

    int lenA = 0, lenB = 0;
    Node *p = A, *q = B;

    while (p) { lenA++; p = p->next; }
    while (q) { lenB++; q = q->next; }

    p = A;
    q = B;
    int diff = lenA - lenB;

    if (diff > 0) {
        for (int i = 0; i < diff; i++) p = p->next;
    } else {
        for (int i = 0; i < -diff; i++) q = q->next;
    }

    while (p && q) {
        if (p == q) return p->data;
        p = p->next;
        q = q->next;
    }

    return -1;
}


void Create(int A[], int n, Node **first) {
    int i;
    Node *t, *last;

    *first = (Node *)malloc(sizeof(Node));
    (*first)->data = A[0];
    (*first)->next = NULL;

    last = *first;

    for (i = 1; i < n; i++) {
        t = (Node *)malloc(sizeof(Node));
        t->data = A[i];
        t->next = NULL;
        last->next = t;
        last = t;
    }

}

void Display(Node *p) {
    while (p != NULL) {
        printf("%d ", p->data);
        p = p->next;
    }
    printf("\n");
}