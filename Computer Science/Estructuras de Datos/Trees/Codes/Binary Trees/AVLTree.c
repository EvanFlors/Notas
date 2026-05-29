#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    int height;
    struct Node *left;
    struct Node *right;
} Node;

/* ----------------------------------------------------------
 * Function Prototypes
 * ---------------------------------------------------------- */

Node *create_node(int data);
Node *insert(Node *root, int key);

Node *right_rotate(Node *);
Node *left_rotate(Node *);

int node_height(Node *root);
int balance_factor(Node *root);

void inorder(Node *root);


int main(void) {

    int values[] = {10, 20, 25, 35, 45, 50, 60};
    int n = sizeof(values) / sizeof(values[0]);
    Node *root = NULL;

    for (int i = 0; i < n; i++) {
        root = insert(root, values[i]);
    }

    inorder(root);
    printf("\n");

    return 0;
}

Node *create_node(int data) {

    Node *node = malloc(sizeof(Node));

    if (node == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }

    node->data = data;
    node->height = 1; // New nodes are initially added at leaf position

    node->left = NULL;
    node->right = NULL;

    return node;

}

int node_height(Node *node) {

    int hr, hl;

    if (node == NULL) {
        return 0;
    }

    hl = node->left ? node->left->height : 0;
    hr = node->right ? node->right->height : 0;

    return (hl > hr ? hl : hr) + 1;
}

int balance_factor(Node *node) {

    if (node == NULL) {
        return 0;
    }

    return node_height(node->left) - node_height(node->right);
}

Node *insert(Node *p, int key) {

    if (p == NULL) {
        return create_node(key);
    }

    if (key < p->data) {
        p->left = insert(p->left, key);
    } else if (key > p->data) {
        p->right = insert(p->right, key);
    }

    p->height = node_height(p);

    // Left Left Case
    if (balance_factor(p) == 2 && balance_factor(p->left) == 1) {
        return right_rotate(p);
    }

    // Right Right Case
    if (balance_factor(p) == -2 && balance_factor(p->right) == -1) {
        return left_rotate(p);
    }

    // Left Right Case
    if (balance_factor(p) == 2 && balance_factor(p->left) == -1) {
        p->left = left_rotate(p->left);
        return right_rotate(p);
    }

    // Right Left Case
    if (balance_factor(p) == -2 && balance_factor(p->right) == 1) {
        p->right = right_rotate(p->right);
        return left_rotate(p);
    }

    return p;
}

Node *right_rotate(Node *p) {

    Node *pl = p->left;
    Node *plr = pl->right;

    pl->right = p;
    p->left = plr;

    p->height = node_height(p);
    pl->height = node_height(pl);

    return pl;
}

Node *left_rotate(Node *p) {

    Node *pr = p->right;
    Node *prl = pr->left;

    pr->left = p;
    p->right = prl;

    p->height = node_height(p);
    pr->height = node_height(pr);

    return pr;

}

void inorder(Node *root) {

    if (root == NULL) {
        return;
    }

    inorder(root->left);

    printf("%d ", root->data);

    inorder(root->right);
}