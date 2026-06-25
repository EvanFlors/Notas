#include <stdio.h>
#include <stdlib.h>

#include "Queue.h"
#include "Stack.h"

void CreateTree(Node **);

Node *BuildTreeFromTraversal(int [], int [], int, int);
int Search(int [], int, int , int);

int Height(Node *);
int Count(Node *);
int Leafs(Node *);

void Preorder(Node *);
void Inorder(Node *);
void Postorder(Node *);

void PreorderIterative(Node *);
void InorderIterative(Node *);
void PostorderIterative(Node *);
void LevelOrder(Node *);

int main() {

    Node *root;
    int preorder[] = {1, 2, 4, 5, 3};
    int inorder[] = {4, 2, 5, 1, 3};
    int n = sizeof(preorder) / sizeof(preorder[0]);

    root = BuildTreeFromTraversal(preorder, inorder, 0, n - 1);
    printf("\n");

    printf("Preorder: ");
    PreorderIterative(root);
    printf("\n");

    printf("Inorder: ");
    InorderIterative(root);
    printf("\n");

    printf("Postorder: ");
    PostorderIterative(root);
    printf("\n");

    printf("Level Order: ");
    LevelOrder(root);
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

Node *BuildTreeFromTraversal(int preorder[], int inorder[], int inStart, int inEnd) {
    if (inStart > inEnd) {
        return NULL;
    }

    static int preIndex = 0;

    Node *root = (Node *)malloc(sizeof(Node));
    root->data = preorder[preIndex++];

    // Leaf node
    if (inStart == inEnd) {
        return root;
    }

    // Find root in inorder
    int splitIndex = Search(inorder, inStart, inEnd, root->data);

    // Build left subtree
    root->left = BuildTreeFromTraversal(preorder, inorder, inStart, splitIndex - 1);

    // Build right subtree
    root->right = BuildTreeFromTraversal(preorder, inorder, splitIndex + 1, inEnd);
    return root;
}

int Search(int arr[], int start, int end, int key) {
    for (int i = start; i <= end; i++) {
        if (arr[i] == key) {
            return i;
        }
    }
    return -1;
}

int Height(Node *root) {
    if (root == NULL) {
        return 0;
    }

    int leftHeight = Height(root->left);
    int rightHeight = Height(root->right);

    return 1 + (leftHeight > rightHeight ? leftHeight : rightHeight);
}

int Count(Node *root) {
    if (root == NULL) {
        return 0;
    }

    return 1 + Count(root->left) + Count(root->right);
}

int Leafs(Node *root) {

    if (root != NULL) {
        x = Leafs(root->left);
        y = Leafs(root->right);

        if (root->left == NULL && root->right == NULL) {
            return 1 + x + y;
        } else {
            return x + y;
        }
    }
    return 0;
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

void PreorderIterative(Node *root) {

    Stack *stack;
    CreateStack(&stack, 100);
    Node *tmp = root;

    while (tmp != NULL || !isStackEmpty(stack)) {
        if (tmp != NULL) {
            printf("%d ", tmp->data);
            Push(stack, tmp);
            tmp = tmp->left;
        } else {
            tmp = Pop(stack);
            tmp = tmp->right;
        }
    }
}

void InorderIterative(Node *root) {

    Stack *stack;
    CreateStack(&stack, 100);

    Node *current = root;

    while (current != NULL || !isStackEmpty(stack)) {

        while (current != NULL) {

            Push(stack, current);
            current = current->left;
        }

        current = Pop(stack);
        printf("%d ", current->data);
        current = current->right;
    }
}

void PostorderIterative(Node *root) {

    Stack *stack;
    CreateStack(&stack, 100);

    Node *current = root;
    Node *lastVisited = NULL;

    while (current != NULL || !isStackEmpty(stack)) {

        // Go as left as possible
        if (current != NULL) {
            Push(stack, current);
            current = current->left;
        } else {
            Node *peekNode = stack->arr[stack->top];

            // If right subtree exists and has
            // not been visited, traverse right.
            if (
                peekNode->right != NULL &&          // Validate if is not leaf node
                lastVisited != peekNode->right      // Avoid visiting right child multiple times
            ) {
                current = peekNode->right;
            } else {
                printf("%d ", peekNode->data);
                lastVisited = Pop(stack);
                current = NULL;
            }
        }
    }
}

void LevelOrder(Node *root) {

    Queue *q;
    CreateQueue(&q, 100);
    enqueue(q, root);

    while (!isEmpty(q)) {
        Node *current = dequeue(q);
        if (current) {
            printf("%d ", current->data);
            enqueue(q, current->left);
            enqueue(q, current->right);
        }
    }

    DestroyQueue(q);
}