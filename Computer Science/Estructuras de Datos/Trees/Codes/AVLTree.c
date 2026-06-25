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

Node *create_node(int);

Node *insert(Node *, int);
Node *delete(Node *, int);

int node_height(Node *);
int balance_factor(Node *);

Node *inorder_successor(Node *);
Node *inorder_predecessor(Node *);

void inorder(Node *);

Node *right_rotate(Node *);
Node *left_rotate(Node *);

int main(void) {

    int values[] = {10, 20, 25, 35, 45, 50, 60};
    int n = sizeof(values) / sizeof(values[0]);
    Node *root = NULL;

    for (int i = 0; i < n; i++) {
        root = insert(root, values[i]);
    }

    inorder(root);
    printf("\n");

    root = delete(root, 35);
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

Node *delete(Node *p, int key) {

    if (p == NULL) {
        return p;
    }

    if (key < p->data) {
        p->left = delete(p->left, key);
    } else if (key > p->data) {
        p->right = delete(p->right, key);
    } else {
        // Node with only one child or no child
        if (p->left == NULL || p->right == NULL) {
            Node *temp = p->left ? p->left : p->right;

            if (temp == NULL) {
                temp = p;
                p = NULL;
            } else {
                *p = *temp; // Copy the contents of the non-empty child
            }

            free(temp);
        } else {
            // Node with two children: Get the inorder successor
            Node *temp = inorder_successor(p->right);

            // Copy the inorder successor's content to this node
            p->data = temp->data;

            // Delete the inorder successor
            p->right = delete(p->right, temp->data);
        }
    }

    if (p == NULL) {
        return p;
    }

    p->height = node_height(p);

    // Left Left Case
    if (balance_factor(p) == 2 && balance_factor(p->left) >= 0) {
        return right_rotate(p);
    }

    // Right Right Case
    if (balance_factor(p) == -2 && balance_factor(p->right) <= 0) {
        return left_rotate(p);
    }

    // Left Right Case
    if (balance_factor(p) == 2 && balance_factor(p->left) < 0) {
        p->left = left_rotate(p->left);
        return right_rotate(p);
    }

    // Right Left Case
    if (balance_factor(p) == -2 && balance_factor(p->right) > 0) {
        p->right = right_rotate(p->right);
        return left_rotate(p);
    }

    return p;
}


Node *inorder_predecessor(Node *root) {

    while (root != NULL && root->right != NULL) {
        root = root->right;
    }

    return root;
}

Node *inorder_successor(Node *root) {

    while (root != NULL && root->left != NULL) {
        root = root->left;
    }

    return root;
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