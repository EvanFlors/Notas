#include <stdio.h>

#define EMPTY       -1
#define TABLE_SIZE  19

int HashFunction(int value, int table_size);
int LinearProbe(int Hash[], int value, int table_size);
int QuadraticProbe(int Hash[], int value, int table_size);

void Insert(int Hash[], int table_size, int value);
int Search(int Hash[], int table_size, int value);
void PrintTable(int Hash[], int table_size);

int main(void)
{
    int A[] = {1, 23, 42, 35, 73, 10, 91, 84, 35};
    int n = sizeof(A) / sizeof(A[0]);

    int H[TABLE_SIZE];

    for (int i = 0; i < TABLE_SIZE; i++) {
        H[i] = EMPTY;
    }

    for (int i = 0; i < n; i++) {
        Insert(H, TABLE_SIZE, A[i]);
    }

    PrintTable(H, TABLE_SIZE);

    int value = 35;
    int index = Search(H, TABLE_SIZE, value);

    if (index != -1)
        printf("\n%d found at index %d\n", value, index);
    else
        printf("\n%d not found\n", value);

    return 0;
}

int HashFunction(int value, int table_size)
{
    return value % table_size;
}

int LinearProbe(int Hash[], int value, int table_size)
{
    int index = HashFunction(value, table_size);

    for (int i = 0; i < table_size; i++) {
        int probe = (index + i) % table_size;

        if (Hash[probe] == EMPTY)
            return probe;
    }

    return -1;
}

int QuadraticProbe(int Hash[], int value, int table_size)
{
    int index = HashFunction(value, table_size);

    for (int i = 0; i < table_size; i++) {
        int probe = (index + i * i) % table_size;

        if (Hash[probe] == EMPTY)
            return probe;
    }

    return -1;
}

void Insert(int Hash[], int table_size, int value)
{
    int index = QuadraticProbe(Hash, value, table_size);

    if (index == -1) {
        printf("Failed to insert %d: table is full\n", value);
        return;
    }

    Hash[index] = value;
}

int Search(int Hash[], int table_size, int value)
{
    int index = HashFunction(value, table_size);

    for (int i = 0; i < table_size; i++) {
        int probe = (index + i * i) % table_size;

        if (Hash[probe] == EMPTY)
            return -1;

        if (Hash[probe] == value)
            return probe;
    }

    return -1;
}

void PrintTable(int Hash[], int table_size)
{
    printf("Hash Table\n");
    printf("----------\n");

    for (int i = 0; i < table_size; i++) {
        if (Hash[i] == EMPTY)
            printf("[%2d] -> NULL\n", i);
        else
            printf("[%2d] -> %d\n", i, Hash[i]);
    }
}