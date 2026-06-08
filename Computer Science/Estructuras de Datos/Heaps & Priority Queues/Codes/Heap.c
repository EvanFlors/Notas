#include <stdio.h>
#include <stdlib.h>

#define SIZE 10

typedef struct {
    int *data;
    int size;
    int length;
} Heap;

void createHeap(Heap **heap);
void createHeapArray(Heap **heap, int arr[], int size);

int *maxHeapifyBuilding(int *arr, int size);
void heapify(int *arr, int size, int idx);

void insert(Heap *heap, int value);
int delete(Heap *heap);

void display(Heap *heap);
void destroyHeap(Heap *heap);

int main() {

    Heap *heap;

    int arr[] = {40, 35, 30, 15, 10, 25, 5};

    createHeap(&heap);

    for (int i = 0; i < 7; i++) {
        heap->data[i] = arr[i];
    }

    heap->length = 7;
    maxHeapifyBuilding(heap->data, 7);

    for (int i = heap->length - 1; i >= 0; i--) {
        printf("Deleted value %d\n", delete(heap));
    }

    display(heap);
    destroyHeap(heap);

    return 0;
}

void createHeapArray(Heap **heap, int arr[], int size) {
    createHeap(heap);

    for (int i = 0; i < size; i++) {
        insert(*heap, arr[i]);
    }

}

int *maxHeapifyBuilding(int *arr, int size) {

    // 2i > n is a leaf node then, i > n / 2 - 1 is the last non-leaf node
    // Don't evaluate leaves
    for (int i = (size / 2) - 1; i >= 0; i--) {
        heapify(arr, size, i);
    }

    return arr;
}

void heapify(int *arr, int size, int idx) {
    int largest = idx;

    int left = 2 * idx + 1;
    int right = 2 * idx + 2;

    if (left < size && arr[left] > arr[largest]) {
        largest = left;
    }

    if (right < size && arr[right] > arr[largest]) {
        largest = right;
    }

    if (largest != idx) {

        int tmp = arr[idx];
        arr[idx] = arr[largest];
        arr[largest] = tmp;

        heapify(arr, size, largest);
    }
}

void createHeap(Heap **heap) {

    *heap = malloc(sizeof(Heap));

    if (*heap == NULL) {
        perror("malloc");
        exit(EXIT_FAILURE);
    }

    (*heap)->size = SIZE;
    (*heap)->length = 0;

    (*heap)->data = malloc(SIZE * sizeof(int));

    if ((*heap)->data == NULL) {
        perror("malloc");
        free(*heap);
        exit(EXIT_FAILURE);
    }
}

void insert(Heap *heap, int value) {

    if (heap->length >= heap->size) {
        printf("Heap is full\n");
        return;
    }

    int idx = heap->length;

    while (
        idx > 0 &&
        value > heap->data[(idx - 1) / 2]
    ) {

        heap->data[idx] =
            heap->data[(idx - 1) / 2];

        idx = (idx - 1) / 2;
    }

    heap->data[idx] = value;
    heap->length++;
}

int delete(Heap *heap) {
    if (heap == NULL || heap->length == 0) {
        fprintf(stderr, "Heap is empty\n");
        return -1;
    }

    int deleted = heap->data[0];

    heap->length--;

    heap->data[0] = heap->data[heap->length];

    int i = 0;

    while (1) {

        int left = 2 * i + 1;
        int right = 2 * i + 2;

        int largest = i;

        if (
            left < heap->length &&
            heap->data[left] > heap->data[largest]
        ) {
            largest = left;
        }

        if (
            right < heap->length &&
            heap->data[right] > heap->data[largest]
        ) {
            largest = right;
        }

        if (largest == i) {
            break;
        }

        int temp = heap->data[i];
        heap->data[i] = heap->data[largest];
        heap->data[largest] = temp;

        i = largest;
    }

    return deleted;
}

void display(Heap *heap) {

    printf("Heap: ");

    for (int i = 0; i < heap->length; i++) {
        printf("%d ", heap->data[i]);
    }

    printf("\n");
}

void destroyHeap(Heap *heap) {

    if (heap == NULL)
        return;

    free(heap->data);
    free(heap);
}