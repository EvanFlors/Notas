#include <stdio.h>
#include <stdlib.h>

#define ELEMENTS 10

void Union(int set[], int x, int y);
int Find(int set[], int x);

int main() {

    int set[ELEMENTS];

    for (int i = 0; i < ELEMENTS; i++) {
        set[i] = -1;
    }

    printf("Find(3): %d\n", Find(set, 3));
    printf("Find(4): %d\n", Find(set, 4));
    Union(set, 3, 4);
    Union(set, 4, 5);
    printf("Find(3): %d\n", Find(set, 3));
    printf("Find(4): %d\n", Find(set, 4));

    for (int i = 0; i < ELEMENTS; i++) {
        printf("%d ", set[i]);
    }

    printf("\n");
    printf("Find(5): %d\n", Find(set, 5));

    return 0;
}

void Union(int set[], int x, int y) {
    if (set[x] < set[y]) {
        set[x] += set[y];
        set[y] = x;
    } else {
        set[y] += set[x];
        set[x] = y;
    }
}

int Find(int set[], int x)
{
    while (set[x] >= 0)
        x = set[x];

    return x;
}