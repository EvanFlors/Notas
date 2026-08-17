#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

#include "Stack.h"

/* ----------------------------------------------------------
 * Function Prototypes
 * ---------------------------------------------------------- */

Node *create_preorder(int [], int);

Node *create_node(int data);
Node *insert(Node *root, int key);
Node *delete_node(Node *root, int key);
Node *search(Node *root, int key);

Node *inorder_predecessor(Node *root);
Node *inorder_successor(Node *root);

void inorder(Node *root);
int height(Node *root);

void destroy_tree(Node *root);


/* ----------------------------------------------------------
 * Main
 * ---------------------------------------------------------- */

int main(void) {

    Node *root = NULL;

    int values[] = {30, 20, 10, 15, 25, 40, 50, 45};

    int n = sizeof(values) / sizeof(values[0]);

    // for (int i = 0; i < n; i++) {
    //     root = insert(root, values[i]);
    // }

    root = create_preorder(values, n);

    printf("Inorder Traversal:\n");

    inorder(root);

    printf("\n");

    int target = 10;

    Node *found = search(root, target);

    if (found != NULL) {
        printf("Found: %d\n", found->data);
    } else {
        printf("%d Not Found\n", target);
    }

    root = delete_node(root, 7);

    printf("\nAfter Deleting 7:\n");

    inorder(root);

    printf("\n");

    destroy_tree(root);

    return 0;
}

/* ----------------------------------------------------------
 * Tree Creation Preorder
 * ---------------------------------------------------------- */
Node *create_preorder(int data[], int n) {

    Stack *st;
    CreateStack(&st, 100);

    Node *t;
    Node *p;
    Node *root;

    int i = 0;

    root = create_node(data[i++]);
    p = root;

    while (i < n) {
        if (data[i] < p->data) {
            Push(st, p);
            t = create_node(data[i++]);
            p->left = t;
            p = t;
        } else {
            int upper_bound =
                isStackEmpty(st)
                ? INT_MAX
                : Top(st)->data;

            if (
                data[i] > p->data &&
                data[i] < upper_bound
            ) {
                t = create_node(data[i++]);
                p->right = t;
                p = t;
            } else {
                p = Pop(st);
            }
        }
    }

    return root;

}

/* ----------------------------------------------------------
 * Node Creation
 * ---------------------------------------------------------- */

Node *create_node(int data) {

    Node *node = malloc(sizeof(Node));

    if (node == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }

    node->data = data;
    node->left = NULL;
    node->right = NULL;

    return node;
}


/* ----------------------------------------------------------
 * Insert
 * ---------------------------------------------------------- */

Node *insert(Node *root, int key) {

    if (root == NULL) {
        return create_node(key);
    }

    if (key < root->data) {

        root->left = insert(root->left, key);

    } else if (key > root->data) {

        root->right = insert(root->right, key);
    }

    return root;
}


/* ----------------------------------------------------------
 * Delete
 * ---------------------------------------------------------- */

Node *delete_node(Node *root, int key) {

    if (root == NULL) {
        return NULL;
    }

    if (key < root->data) {

        root->left = delete_node(root->left, key);

    } else if (key > root->data) {

        root->right = delete_node(root->right, key);

    } else {

        /* Leaf Node */
        if (root->left == NULL && root->right == NULL) {

            free(root);

            return NULL;
        }

        /* Replace with predecessor or successor */
        if (height(root->left) > height(root->right)) {

            Node *pred = inorder_predecessor(root->left);

            root->data = pred->data;

            root->left = delete_node(root->left, pred->data);

        } else {

            Node *succ = inorder_successor(root->right);

            root->data = succ->data;

            root->right = delete_node(root->right, succ->data);
        }
    }

    return root;
}


/* ----------------------------------------------------------
 * Search
 * ---------------------------------------------------------- */

Node *search(Node *root, int key) {

    while (root != NULL) {

        if (key < root->data) {

            root = root->left;

        } else if (key > root->data) {

            root = root->right;

        } else {

            return root;
        }
    }

    return NULL;
}


/* ----------------------------------------------------------
 * Inorder Predecessor
 * ---------------------------------------------------------- */

Node *inorder_predecessor(Node *root) {

    while (root != NULL && root->right != NULL) {
        root = root->right;
    }

    return root;
}


/* ----------------------------------------------------------
 * Inorder Successor
 * ---------------------------------------------------------- */

Node *inorder_successor(Node *root) {

    while (root != NULL && root->left != NULL) {
        root = root->left;
    }

    return root;
}


/* ----------------------------------------------------------
 * Inorder Traversal
 * ---------------------------------------------------------- */

void inorder(Node *root) {

    if (root == NULL) {
        return;
    }

    inorder(root->left);

    printf("%d ", root->data);

    inorder(root->right);
}


/* ----------------------------------------------------------
 * Height
 * ---------------------------------------------------------- */

int height(Node *root) {

    if (root == NULL) {
        return 0;
    }

    int left_height = height(root->left);

    int right_height = height(root->right);

    return (left_height > right_height
        ? left_height
        : right_height) + 1;
}


/* ----------------------------------------------------------
 * Cleanup
 * ---------------------------------------------------------- */

void destroy_tree(Node *root) {

    if (root == NULL) {
        return;
    }

    destroy_tree(root->left);

    destroy_tree(root->right);

    free(root);
}