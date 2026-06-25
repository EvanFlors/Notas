#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int data;
    struct Node *next;
} Node;

void CreateLinkedList(Node **head, int arr[], int n);
Node *CreateNode(int data);

int *InsertionSort(int arr[], int n);
int *InsertionSortLoops(int arr[], int n);
Node *InsertionSortLinkedList(Node *head);

int main(void)
{
    int Arr[] = {5, 1, 4, 2, 8};
    int n = sizeof(Arr) / sizeof(Arr[0]);

    InsertionSort(Arr, n);

    printf("Sorted array: ");
    for (int i = 0; i < n; i++)
        printf("%d ", Arr[i]);
    printf("\n");

    Node *head = NULL;

    int listData[] = {5, 1, 4, 2, 8};
    int listSize = sizeof(listData) / sizeof(listData[0]);

    CreateLinkedList(&head, listData, listSize);

    head = InsertionSortLinkedList(head);

    printf("Sorted list: ");
    for (Node *current = head; current != NULL; current = current->next)
        printf("%d ", current->data);

    printf("\n");

    return 0;
}

int *InsertionSort(int arr[], int n) {

    int i, j, x;

    for (i = 1; i < n - 1; i++) {
        j = i - 1;
        x = arr[i];

        while (j > -1 && arr[j] > x) {
            arr[j + 1] = arr[j];
            j--;
        }

        arr[j + 1] = x;
    }

    return arr;
}

int *InsertionSortLoops(int arr[], int n) {

    int i, j, x;

    for (i = 1; i < n - 1; i++) {
        x = arr[i];
        for (j = i - 1; j > -1; j--) {
            if (arr[j] > x) {
                arr[j + 1] = arr[j];
            } else {
                break;
            }
        }
        arr[j + 1] = x;
    }
    return arr;
}

Node *InsertionSortLinkedList(Node *head)
{
    Node *first = NULL;
    Node *current = head;

    while (current != NULL)
    {
        Node *tail = current->next;

        if (first == NULL || current->data < first->data)
        {
            current->next = first;
            first = current;
        }
        else
        {
            Node *temp = first;

            while (temp->next != NULL &&
                   temp->next->data < current->data)
            {
                temp = temp->next;
            }

            current->next = temp->next;
            temp->next = current;
        }

        current = tail;
    }

    return first;
}

void CreateLinkedList(Node **head, int arr[], int n) {

    int i;

    *head = CreateNode(arr[0]);
    Node *current = *head;

    for (i = 1; i < n; i++) {
        Node *new_node = CreateNode(arr[i]);
        current->next = new_node;
        current = new_node;
    }
}

Node *CreateNode(int data) {
    Node *node = (Node *)malloc(sizeof(Node));
    node->data = data;
    node->next = NULL;

    return node;
}