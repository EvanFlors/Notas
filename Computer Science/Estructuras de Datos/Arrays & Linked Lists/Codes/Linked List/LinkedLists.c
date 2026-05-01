#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void Create(int [], int, Node **);

int Sorted(Node *);
int Count(Node *);
int Sum(Node *);
int Max(Node *);

Node *Search(Node *, int);
Node *SearchRecursive(Node *, int);
Node *SearchImproved(Node *, int);

void Insert(Node **, int, int);
void SortedInsert(Node **, int);

int Delete(Node **, int);

void Reverse(Node **);

void RemoveDuplicatesSorted(Node **);

void DisplayRecursive(Node *);
void Display(Node *);

int main() {

    int A[] = {1, 1, 1, 2, 3, 3, 5, 7, 10, 15};
    Node *head = NULL;
    Create(A, 10, &head);
    RemoveDuplicatesSorted(&head);

    Display(head);

    printf("Sorted: %d\n", Sorted(head));

    return 0;
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

int Sorted(Node *p) {
    int x = -65536;

    while (p) {
        if (p->data < x) {
            return 0;
        }
        x = p->data;
        p = p->next;
    }

    return 1;
}

int Count(Node *p) {
    int count = 0;
    while (p) {
        count++;
        p = p->next;
    }
    return count;
}

int Sum(Node *p) {
    int sum = 0;
    while (p) {
        sum += p->data;
        p = p->next;
    }
    return sum;
}

int Max(Node *p) {
    int max = p->data;
    while (p) {
        if (p->data > max) {
            max = p->data;
        }
        p = p->next;
    }
    return max;
}

Node *SearchImproved(Node *p, int key) {
    Node *first = p;
    Node *q = NULL;

    while (p != NULL) {
        if (key == p->data) {
            if (q != NULL) {
                q->next = p->next;
            }
            p->next = first;
            first = p;
            return first;
        }
        q = p;
        p = p->next;
    }

    return NULL;
}

Node *Search(Node *p, int key) {
    while (p) {
        if (p->data == key) {
            return p;
        }
        p = p->next;
    }
    return NULL;
}

Node *SearchRecursive(Node *p, int key) {
    if (!p) return NULL;

    if (p->data == key) {
        return p;
    }

    return SearchRecursive(p->next, key);
}

void Insert(Node **first, int x, int position) {
    Node *t, *p;

    if (position == 0) {
        t = (Node *)malloc(sizeof(Node));
        t->data = x;
        t->next = *first;
        *first = t;
    } else if (position > 0) {
        p = *first;

        for (int i = 0; i < position - 1 && p != NULL; i++) {
            p = p->next;
        }

        if (p != NULL) {
            t = (Node *)malloc(sizeof(Node));
            t->data = x;
            t->next = p->next;
            p->next = t;
        }

    }

}

void SortedInsert(Node **first, int x) {
    Node *p = *first;
    Node *t, *q = NULL;

    t = (Node *)malloc(sizeof(Node));
    t->data = x;
    t->next = NULL;

    if (p == NULL) {
        *first = t;
    } else {
        while (p && p->data < x) {
            q = p;
            p = p->next;
        }

        if (p == *first) {
            t->next = *first;
            *first = t;
        } else {
            t->next = q->next;
            q->next = t;
        }
    }
}

int Delete(Node **first, int position) {
    Node *p, *q;

    int x = -1, i;

    if (position == 0) {
        p = *first;
        x = p->data;
        *first = p->next;
        free(p);
    } else {
        p = *first;
        q = NULL;

        for (i = 0; i < position && p != NULL; i++) {
            q = p;
            p = p->next;
        }

        if (p != NULL) {
            x = p->data;
            q->next = p->next;
            free(p);
        }
    }

    return x;
}

void Reverse(Node **first) {



}

void RemoveDuplicatesSorted(Node **first) {
    Node *q = *first;
    Node *p = q->next;

    while (p != NULL) {
        if (p->data != q->data) {
            q = p;
            p = p->next;
        } else {
            q->next = p->next;
            free(p);
            p = q->next;
        }
    }
}

void Display(Node *p) {
    while (p != NULL) {
        printf("%d ", p->data);
        p = p->next;
    }
    printf("\n");
}

void DisplayRecursive(Node *p) {
    if (!p) return;

    printf("%d ", p->data);
    DisplayRecursive(p->next);
}