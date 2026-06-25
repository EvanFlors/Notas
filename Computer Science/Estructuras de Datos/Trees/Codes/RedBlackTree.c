#include <stdio.h>
#include <stdlib.h>

typedef enum {
    RED,
    BLACK
} Color;

typedef struct Node {
    int data;
    Color color;
    struct Node *left;
    struct Node *right;
    struct Node *parent;
} Node;

Node *NIL;

void insert(Node **, int);

void fixViolation(Node **, Node *);
void transplant(Node **, Node *, Node *);

void delete(Node **, Node *);
void deleteNode(Node **, Node *);
void deleteKey(Node **, int);

void inorder(Node *);

void initializeNIL();

void leftRotate(Node **, Node *);
void rightRotation(Node **, Node *);

Node *BSTInsert(Node *, Node *);
Node *treeMinimum(Node *);
Node *search(Node *, int);
Node *createNode(int);

int main() {

    initializeNIL();

    Node *root = NULL;

    int values[] = {
        10, 20, 30, 15, 25, 5, 1
    };

    int n = sizeof(values) / sizeof(values[0]);

    for (int i = 0; i < n; i++)
        insert(&root, values[i]);

    deleteKey(&root, 15);

    inorder(root);
    printf("\n");

    return 0;
}

void insert(Node **root, int data) {
    Node *pt = createNode(data);
    *root = BSTInsert(*root, pt);
    fixViolation(root, pt);
}

void delete(Node **root, Node *x) {

    while (
        (x != *root) &&
        (x->color == BLACK)
    ) {
        if (x == x->parent->left) {
            Node *w = x->parent->right;

            // Case 1: Sibling is red
            if (w->color == RED) {
                w->color = BLACK;
                x->parent->color = RED;
                leftRotate(root, x->parent);
                w = x->parent->right;
            }

            // Case 2: Both children are black
            if (
                (w->left->color == BLACK) &&
                (w->right->color == BLACK)
            ) {
                w->color = RED;
                x = x->parent;
            } else {
                // Case 3: Sibling Black + Near Child Red
                if (w->right->color == BLACK) {
                    w->left->color = BLACK;
                    w->color = RED;
                    rightRotation(root, w);
                    w = x->parent->right;
                }

                // Case 4: Sibling Black + Far Child Red
                w->color = x->parent->color;
                x->parent->color = BLACK;
                w->right->color = BLACK;
                leftRotate(root, x->parent);
                x = *root;
            }

        } else {
            Node *w = x->parent->left;

            // Case 1: Sibling is red
            if (w->color == RED) {
                w->color = BLACK;
                x->parent->color = RED;
                rightRotation(root, x->parent);
                w = x->parent->left;
            }

            // Case 2: Both children are black
            if (
                (w->right->color == BLACK) &&
                (w->left->color == BLACK)
            ) {
                w->color = RED;
                x = x->parent;
            } else {
                // Case 3: At least one child is red
                if (w->left->color == BLACK) {
                    w->right->color = BLACK;
                    w->color = RED;
                    leftRotate(root, w);
                    w = x->parent->left;
                }
                w->color = x->parent->color;
                x->parent->color = BLACK;
                w->left->color = BLACK;
                rightRotation(root, x->parent);
                x = *root;
            }
        }
    }

    x->color = BLACK;
}

Node *BSTInsert(Node *root, Node *pt) {
    if (root == NULL || root == NIL) {
        return pt;
    }

    if (pt->data < root->data) {
        root->left = BSTInsert(root->left, pt);
        root->left->parent = root;
    } else if (pt->data > root->data) {
        root->right = BSTInsert(root->right, pt);
        root->right->parent = root;
    }

    return root;
}

void fixViolation(Node **root, Node *pt) {

    Node *parent_pt = NULL;
    Node *grandparent_pt = NULL;

    while(
        (pt != *root) &&
        (pt->color == RED) &&
        (pt->parent->color == RED)
    ) {
        parent_pt = pt->parent;
        grandparent_pt = parent_pt->parent;

        // Case A: Parent is left child of grandparent
        if (parent_pt == grandparent_pt->left) {
            Node *uncle_pt = grandparent_pt->right;

            // Case 1: Uncle is red (recoloring)
            if (uncle_pt != NULL && uncle_pt->color == RED) {
                grandparent_pt->color = RED;
                parent_pt->color = BLACK;
                uncle_pt->color = BLACK;
                pt = grandparent_pt;  // Move up the tree
            } else {  // Case 2 & 3: Uncle is black (rotation needed)
                if (pt == parent_pt->right) {
                    leftRotate(root, parent_pt);
                    pt = parent_pt;
                    parent_pt = pt->parent;
                }
                rightRotation(root, grandparent_pt);
                Color temp_color = parent_pt->color;
                parent_pt->color = grandparent_pt->color;
                grandparent_pt->color = temp_color;
                pt = parent_pt;  // Move up the tree
            }
        } else {  // Case B: Parent is right child of grandparent
            Node *uncle_pt = grandparent_pt->left;

            // Case 1: Uncle is red (recoloring)
            if ((uncle_pt != NULL) && (uncle_pt->color == RED)) {
                grandparent_pt->color = RED;
                parent_pt->color = BLACK;
                uncle_pt->color = BLACK;
                pt = grandparent_pt;  // Move up the tree
            } else {  // Case 2 & 3: Uncle is black (rotation needed)
                if (pt == parent_pt->left) {
                    rightRotation(root, parent_pt);
                    pt = parent_pt;
                    parent_pt = pt->parent;
                }
                leftRotate(root, grandparent_pt);
                Color temp_color = parent_pt->color;
                parent_pt->color = grandparent_pt->color;
                grandparent_pt->color = temp_color;
                pt = parent_pt;  // Move up the tree
            }
        }
    }

    (*root)->color = BLACK;  // Ensure root is always black
}

Node *createNode(int data) {

    Node *new_node = malloc(sizeof(Node));
    if (new_node == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }

    new_node->data = data;
    new_node->color = RED;  // New nodes are red by default

    new_node->left = NIL;
    new_node->right = NIL;
    new_node->parent = NIL;

    return new_node;
}

void deleteNode(Node **root, Node *z) {

    Node *y = z;
    Node *x;

    Color y_original_color = y->color;

    if (z->left == NIL) {
        x = z->right;
        transplant(root, z, z->right);
    } else if (z->right == NIL) {
        x = z->left;
        transplant(root, z, z->left);
    } else {
        y = treeMinimum(z->right); // Find successor
        y_original_color = y->color;
        x = y->right;

        if (y->parent == z) {
            x->parent = y;
        } else {
            transplant(root, y, y->right);
            y->right = z->right;
            y->right->parent = y;
        }

        transplant(root, z, y);
        y->left = z->left;
        y->left->parent = y;
        y->color = z->color;
    }

    free(z);

    if (y_original_color == BLACK) {
        delete(root, x);
    }
}

void deleteKey(Node **root, int key) {

    Node *z = search(*root, key);

    if (z != NIL)
        deleteNode(root, z);
}

void leftRotate(Node **root, Node *x) {
    Node *y = x->right;
    x->right = y->left;

    if (y->left) {
        y->left->parent = x;
    }

    y->parent = x->parent;

    if (x->parent == NIL) {
        *root = y;  // Update root if x is root
    } else if (x == x->parent->left) {
        x->parent->left = y;
    } else {
        x->parent->right = y;
    }

    y->left = x;
    x->parent = y;
}

void rightRotation(Node **root, Node *x) {
    Node *y = x->left;
    x->left = y->right;

    if (y->right) {
        y->right->parent = x;
    }

    y->parent = x->parent;

    if (x->parent == NIL) {
        *root = y;  // Update root if x is root
    } else if (x == x->parent->right) {
        x->parent->right = y;
    } else {
        x->parent->left = y;
    }

    y->right = x;
    x->parent = y;
}

Node *search(Node *root, int key) {
    Node *current = root;

    while (current != NIL) {
        if (key < current->data) {
            current = current->left;
        } else if (key > current->data) {
            current = current->right;
        } else {
            return current;  // Key found
        }
    }

    return NULL;  // Key not found
}

void transplant(Node **root, Node *u, Node *v) {

    if (u->parent == NIL) {
        *root = v;  // Update root if u is root
    } else if (u == u->parent->left) {
        u->parent->left = v;
    } else {
        u->parent->right = v;
    }

    v->parent = u->parent;
}

Node *treeMinimum(Node *node) {
    while (node->left != NIL) {
        node = node->left;
    }
    return node;
}

void initializeNIL() {
    NIL = (Node *)malloc(sizeof(Node));
    NIL->color = BLACK;

    NIL->left = NIL;
    NIL->right = NIL;
    NIL->parent = NIL;

}

void inorder(Node *root) {

    if (root == NIL)
        return;

    inorder(root->left);

    printf("%d(%c) ",
           root->data,
           root->color == RED ? 'R' : 'B');

    inorder(root->right);
}