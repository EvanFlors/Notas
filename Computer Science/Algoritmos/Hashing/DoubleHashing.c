#include <stdio.h>

#define EMPTY -1
#define TABLE_SIZE 17
#define SECOND_HASH_PRIME 13

int HashFunction(int value, int table_size);
int JumpHash(int value);
int DoubleHashProbe(int value, int attempt, int table_size);

void Insert(int Hash[], int table_size, int value);
int Search(int Hash[], int table_size, int value);
void PrintTable(int Hash[], int table_size);

int main(void)
{
    int A[] = {5, 15, 25, 35, 45, 65, 75};
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

int JumpHash(int value)
{
    return SECOND_HASH_PRIME - (value % SECOND_HASH_PRIME);
}

int DoubleHashProbe(int value, int attempt, int table_size)
{
    int h1 = HashFunction(value, table_size);
    int h2 = JumpHash(value);

    return (h1 + attempt * h2) % table_size;
}

void Insert(int Hash[], int table_size, int value)
{
    for (int i = 0; i < table_size; i++) {

        int probe = DoubleHashProbe(value, i, table_size);

        if (Hash[probe] == EMPTY) {
            Hash[probe] = value;
            return;
        }
    }

    printf("Failed to insert %d: table is full\n", value);
}

int Search(int Hash[], int table_size, int value)
{
    for (int i = 0; i < table_size; i++) {

        int probe = DoubleHashProbe(value, i, table_size);

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