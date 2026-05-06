#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void Create(int [], int, Node **);

Node *Concatenate(Node *, Node *);
Node *Merge(Node *, Node *);

int Loop(Node *);
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
void ReverseRecursive(Node **, Node *, Node *);

void RemoveDuplicatesSorted(Node **);
void RemoveDuplicatesUnsorted(Node **);

void DisplayRecursive(Node *);
void Display(Node *);

int main() {

    int A[] = {1, 1, 1, 2, 3, 3, 5, 7, 10, 15};
    int B[] = {1, 2, 3, 5, 12, 15};

    Node *first = NULL;
    Node *second = NULL;

    Create(A, 10, &first);
    Create(B, 6, &second);

    Node *merged = Concatenate(first, second);

    Display(merged);

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

int Loop(Node *p) {

    Node *fast, *slow;
    fast = slow = p;

    do {
        fast = fast->next;
        slow = slow->next;
        fast = fast ? fast->next : NULL;

    } while (fast && slow && fast != slow);

    return fast == slow;
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

    Node *prev = NULL;
    Node *current = *first;
    Node *next = NULL;

    while (current != NULL) {
        next = current->next;
        current->next = prev;
        prev = current;
        current = next;
    }

    *first = prev;
}

void ReverseRecursive(Node **first, Node *current, Node *prev) {
    if (current == NULL) {
        *first = prev;
        return;
    }

    Node *next = current->next;
    current->next = prev;
    ReverseRecursive(first, next, current);
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

void RemoveDuplicatesUnsorted(Node **first) {

    Node *current = *first;
    Node *prev = NULL;
    Node *temp = NULL;

    while (current != NULL) {
        temp = *first;
        prev = NULL;

        while (temp != current) {
            if (temp->data == current->data) {
                if (prev == NULL) {
                    *first = temp->next;
                } else {
                    prev->next = temp->next;
                }
                free(temp);
                temp = (prev == NULL) ? *first : prev->next;
            } else {
                prev = temp;
                temp = temp->next;
            }
        }
        current = current->next;
    }
}

Node *Concatenate(Node *p, Node *q) {

    Node *t = p;

    while (p->next != NULL)
        p = p->next;

    p->next = q;

    return t;
}

Node *Merge(Node *p, Node *q) {

    if (!p) return q;
    if (!q) return p;

    Node *t, *last;

    if (p->data <= q->data) {
        t = last = p;
        p = p->next;
    } else {
        t = last = q;
        q = q->next;
    }

    while (p && q) {
        if (p->data <= q->data) {
            last->next = p;
            last = p;
            p = p->next;
        } else {
            last->next = q;
            last = q;
            q = q->next;
        }
    }

    last->next = p ? p : q;

    return t;
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