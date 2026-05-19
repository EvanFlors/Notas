#include <stdio.h>
#include <stdlib.h>

#include "Queue.h"

void CreateTree(Node **root);

void Preorder(Node *root);
void Inorder(Node *root);
void Postorder(Node *root);

int main() {

    Node *root;
    CreateTree(&root);

    printf("Preorder: ");
    Preorder(root);
    printf("\n");

    printf("Inorder: ");
    Inorder(root);
    printf("\n");

    printf("Postorder: ");
    Postorder(root);
    printf("\n");

    return 0;
}

void CreateTree(Node **root) {

    int x;
    Node *p, *t;

    Queue *q;
    CreateQueue(&q, 100);

    printf("Enter root value: ");
    scanf("%d", &x);
    *root = (Node *)malloc(sizeof(Node));
    (*root)->data = x;
    (*root)->left = (*root)->right = NULL;
    enqueue(q, *root);

    while(!isEmpty(q)) {
        p = dequeue(q);

        printf("Enter left child of %d: ", p->data);
        scanf("%d", &x);
        if (x != -1) {
            t = (Node *)malloc(sizeof(Node));
            t->data = x;
            t->left = t->right = NULL;
            p->left = t;
            enqueue(q, t);
        }

        printf("Enter right child of %d: ", p->data);
        scanf("%d", &x);
        if (x != -1) {
            t = (Node *)malloc(sizeof(Node));
            t->data = x;
            t->left = t->right = NULL;
            p->right = t;
            enqueue(q, t);
        }
    }

    DestroyQueue(q);
}

void Preorder(Node *root) {
    if (root) {
        printf("%d ", root->data);
        Preorder(root->left);
        Preorder(root->right);
    }
}

void Inorder(Node *root) {
    if (root) {
        Inorder(root->left);
        printf("%d ", root->data);
        Inorder(root->right);
    }
}

void Postorder(Node *root) {
    if (root) {
        Postorder(root->left);
        Postorder(root->right);
        printf("%d ", root->data);
    }
}