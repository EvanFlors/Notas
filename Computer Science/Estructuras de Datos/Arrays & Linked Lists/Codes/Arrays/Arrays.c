#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════════════════
// Array Structure Definition
//
// Given a size and a length, the array can hold a maximum of 'size' elements,
// but currently contains 'length' elements.
//
// Functions:
//
// Display: Show the elements of the array
// Append: Add an element to the end of the array
// Insert: Add an element at a specific index
// Delete: Remove an element from a specific index
// Reverse: Reverse the order of elements in the array
// Rearrange: Rearrange elements based on a specific criterion
// isSorted: Check if the array is sorted
// isEmpty: Check if the array is empty
//
// Get: Retrieve an element at a specific index
// Set: Update an element at a specific index
// Max: Find the maximum element in the array
// Min: Find the minimum element in the array
// Average: Calculate the average of the elements in the array
// Sum: Calculate the sum of the elements in the array
//
// Merge: Combine two arrays into one
// Union: Combine two arrays and remove duplicates
// Intersection: Find common elements between two arrays
// Difference: Find elements in one array but not in the other
//
// Linear Search: Find an element in the array
// Binary Search: Find an element in a sorted array
// Recursive Binary Search: Find an element in a sorted array (recursive)
// ════════════════════════════════════════════════════════════════════════════════

typedef struct Array {
    int *data;
    int size;
    int length;
} Array;

Array *CreateCLI();
void Display(Array);
void Append(Array *, int);
void Insert(Array *, int, int);
void Delete(Array *, int);
void Reverse(Array *);
void Rearrange(Array *);
int isSorted(Array *);
int isEmpty(Array *);

int Get(Array *, int);
int Set(Array *, int, int);
int Max(Array *);
int Min(Array *);
int Average(Array *);
int Sum(Array *);

Array *Merge(Array *, Array *);
Array *Union(Array *, Array *);
Array *Intersection(Array *, Array *);
Array *Difference(Array *, Array *);

int LinearSearch(Array *, int);
int BinarySearch(Array *, int);
int RecursiveBinarySearch(Array *, int, int, int);

// --------------------------------------------------------------------- //

int main(void) {
    Array arr = {(int[10]){1, 2, 3, 4, 5}, 10, 5};
    Array arr2 = {(int[10]){1, 2, 3, 9, 10}, 10, 5};

    Array *merged = Difference(&arr, &arr2);

    Display(arr);
    Display(arr2);
    Display(*merged);

    return 0;
}

// --------------------------------------------------------------------- //

Array *CreateCLI() {
    Array *arr = malloc(sizeof(Array));
    if (arr == NULL) {
        printf("Memory allocation failed\n");
        return NULL;
    }
    arr->data = NULL;
    arr->size = 0;
    arr->length = 0;

    printf("Enter size of array: ");
    scanf("%d", &arr->size);

    arr->data = malloc(arr->size * sizeof(int));

    if (arr->data == NULL) {
        printf("Memory allocation failed\n");
        free(arr);
        return NULL;
    }

    printf("Enter number of elements to insert: ");
    scanf("%d", &arr->length);

    if (arr->length > arr->size) {
        printf("Cannot insert more elements than allocated size\n");
        free(arr->data);
        free(arr);
        return NULL;
    }

    printf("Enter %d elements:\n", arr->length);
    for (int i = 0; i < arr->length; i++) {
        scanf("%d", &arr->data[i]);
    }

    return arr;
}

// --------------------------------------------------------------------- //

void Display(Array arr) {
    printf("Array elements: ");
    for (int i = 0; i < arr.length; i++) {
        printf("%d ", arr.data[i]);
    }
    printf("\n");
}

// --------------------------------------------------------------------- //

void Append(Array *arr, int value) {
    if (arr->length < arr->size) {
        arr->data[arr->length++] = value;
    } else {
        printf("Array is full. Cannot append %d\n", value);
    }
}

void Insert(Array *arr, int index, int value) {
    if (index < 0 || index > arr->length || arr->length >= arr->size) {
        printf("Invalid index or array is full. Cannot insert %d at index %d\n", value, index);
        return;
    }
    for (int i = arr->length; i > index; i--) {
        arr->data[i] = arr->data[i - 1];
    }
    arr->data[index] = value;
    arr->length++;
}

void Delete(Array *arr, int index) {
    if (index < 0 || index >= arr->length) {
        printf("Invalid index. Cannot delete element at index %d\n", index);
        return;
    }
    for (int i = index; i < arr->length - 1; i++) {
        arr->data[i] = arr->data[i + 1];
    }
    arr->length--;

}

void Reverse(Array *arr) {
    if (arr->length == 0) {
        printf("Array is empty. Cannot reverse.\n");
        return;
    }

    int start = 0, end = arr->length - 1;

    while(start < end) {
        int temp = arr->data[start];
        arr->data[start] = arr->data[end];
        arr->data[end] = temp;
        start++;
        end--;
    }
}

void Rearrange(Array *arr) {
    int i = 0, j = arr->length - 1;

    while(i < j) {
        while(arr->data[i] < 0) {
            i++;
        }
        while(arr->data[j] >= 0) {
            j--;
        }
        if (i < j) {
            int temp = arr->data[i];
            arr->data[i] = arr->data[j];
            arr->data[j] = temp;
        }
    }
}

Array *Merge(Array *arr1, Array *arr2) {
    if (arr1 == NULL || arr2 == NULL) {
        printf("Invalid arrays. Cannot merge.\n");
        return NULL;
    }

    Array *merged = malloc(sizeof(Array));
    if (merged == NULL) {
        printf("Memory allocation failed\n");
        return NULL;
    }

    merged->data = malloc((arr1->length + arr2->length) * sizeof(int));
    if (merged->data == NULL) {
        printf("Memory allocation failed\n");
        free(merged);
        return NULL;
    }

    merged->length = 0;
    merged->size = arr1->length + arr2->length;

    int i = 0, j = 0;
    while (i < arr1->length && j < arr2->length) {
        if (arr1->data[i] < arr2->data[j]) {
            merged->data[merged->length++] = arr1->data[i++];
        } else {
            merged->data[merged->length++] = arr2->data[j++];
        }
    }

    while (i < arr1->length) {
        merged->data[merged->length++] = arr1->data[i++];
    }

    while (j < arr2->length) {
        merged->data[merged->length++] = arr2->data[j++];
    }

    return merged;
}

int isSorted(Array *arr) {
    for (int i = 0; i < arr->length - 1; i++) {
        if (arr->data[i] > arr->data[i + 1]) {
            return 0;
        }
    }
    return 1;
}

int isEmpty(Array *arr) {
    return arr->length == 0;
}

// --------------------------------------------------------------------- //

int Get(Array *arr, int index) {
    if (index < 0 || index >= arr->length) {
        printf("Invalid index. Cannot get element at index %d\n", index);
        return -1;
    }
    return arr->data[index];
}

int Set(Array *arr, int index, int value) {
    if (index < 0 || index >= arr->length) {
        printf("Invalid index. Cannot set element at index %d\n", index);
        return -1;
    }
    arr->data[index] = value;
    return 0;
}

int Max(Array *arr) {
    if (arr->length == 0) {
        printf("Array is empty. Cannot find max.\n");
        return -1;
    }

    int max = arr->data[0];
    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] > max) {
            max = arr->data[i];
        }
    }
    return max;
}

int Min(Array *arr) {
    if (arr->length == 0) {
        printf("Array is empty. Cannot find max.\n");
        return -1;
    }

    int min = arr->data[0];
    for (int i = 1; i < arr->length; i++) {
        if (arr->data[i] < min) {
            min = arr->data[i];
        }
    }
    return min;
}

int Sum(Array *arr) {
    int sum = 0;
    for (int i = 0; i < arr->length; i++) {
        sum += arr->data[i];
    }
    return sum;
}

int Average(Array *arr) {
    if (arr->length == 0) {
        printf("Array is empty. Cannot calculate average.\n");
        return -1;
    }

    int sum = 0;
    for (int i = 0; i < arr->length; i++) {
        sum += arr->data[i];
    }
    return sum / arr->length;
}

// --------------------------------------------------------------------- //

Array *Union(Array *arr1, Array *arr2) {
    if (arr1 == NULL || arr2 == NULL) {
        printf("Invalid arrays. Cannot merge.\n");
        return NULL;
    }

    Array *merged = malloc(sizeof(Array));
    if (merged == NULL) {
        printf("Memory allocation failed\n");
        return NULL;
    }

    merged->data = malloc((arr1->length + arr2->length) * sizeof(int));
    if (merged->data == NULL) {
        printf("Memory allocation failed\n");
        free(merged);
        return NULL;
    }

    merged->length = 0;
    merged->size = arr1->length + arr2->length;

    int i = 0, j = 0;
    while (i < arr1->length && j < arr2->length) {
        if (arr1->data[i] < arr2->data[j]) {
            merged->data[merged->length++] = arr1->data[i++];
        } else if (arr1->data[j] < arr2->data[i]) {
            merged->data[merged->length++] = arr2->data[j++];
        } else {
            merged->data[merged->length++] = arr1->data[i++];
            j++;
        }
    }

    while (i < arr1->length) {
        merged->data[merged->length++] = arr1->data[i++];
    }
    while (j < arr2->length) {
        merged->data[merged->length++] = arr2->data[j++];
    }

    return merged;
}

Array *Intersection(Array *arr1, Array *arr2) {
    if (arr1 == NULL || arr2 == NULL) {
        printf("Invalid arrays. Cannot find intersection.\n");
        return NULL;
    }

    Array *merged = malloc(sizeof(Array));
    if (merged == NULL) {
        printf("Memory allocation failed\n");
        return NULL;
    }

    merged->data = malloc((arr1->length + arr2->length) * sizeof(int));
    if (merged->data == NULL) {
        printf("Memory allocation failed\n");
        free(merged);
        return NULL;
    }

    merged->length = 0;
    merged->size = arr1->length + arr2->length;

    int i = 0, j = 0;
    while (i < arr1->length && j < arr2->length) {
        if (arr1->data[i] < arr2->data[j]) {
            i++;
        } else if (arr1->data[j] < arr2->data[i]) {
            j++;
        } else {
            merged->data[merged->length++] = arr1->data[i++];
            j++;
        }
    }

    return merged;
}

Array *Difference(Array *arr1, Array *arr2) {
    if (arr1 == NULL || arr2 == NULL) {
        printf("Invalid arrays. Cannot find difference.\n");
        return NULL;
    }

    Array *merged = malloc(sizeof(Array));
    if (merged == NULL) {
        printf("Memory allocation failed\n");
        return NULL;
    }

    merged->data = malloc((arr1->length + arr2->length) * sizeof(int));
    if (merged->data == NULL) {
        printf("Memory allocation failed\n");
        free(merged);
        return NULL;
    }

    merged->length = 0;
    merged->size = arr1->length + arr2->length;

    int i = 0, j = 0;
    while (i < arr1->length && j < arr2->length) {
        if (arr1->data[i] < arr2->data[j]) {
            merged->data[merged->length++] = arr1->data[i++];
        } else if (arr1->data[j] < arr2->data[i]) {
            j++;
        } else {
            i++;
            j++;
        }
    }

    while (i < arr1->length) {
        merged->data[merged->length++] = arr1->data[i++];
    }

    return merged;
}

// --------------------------------------------------------------------- //

int LinearSearch(Array *arr, int key) {
    for (int i = 0; i < arr->length; i++) {
        if (arr->data[i] == key) {
            return i;
        }
    }
    return -1;
}

int BinarySearch(Array *arr, int key) {
    int mid, l = 0;
    int h = arr->length - 1;

    while(l <= h) {
        mid = (l + h) / 2;
        if (arr->data[mid] == key) {
            return mid;
        } else if (arr->data[mid] < key) {
            l = mid + 1;
        } else {
            h = mid - 1;
        }
    }

    return -1;
}

int RecursiveBinarySearch(Array *arr, int key, int l, int h) {
    if (l > h) {
        return -1;
    }

    int mid = (l + h) / 2;

    if (arr->data[mid] == key) {
        return mid;
    } else if (arr->data[mid] < key) {
        return RecursiveBinarySearch(arr, key, mid + 1, h);
    } else {
        return RecursiveBinarySearch(arr, key, l, mid - 1);
    }

}
