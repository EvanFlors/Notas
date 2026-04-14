#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Find duplicates in a String
//
// Given: A string
// Returns: A list of duplicate characters
//
// Functions:
// - findDuplicatesComparingAll(char *): Finds duplicates by comparing all characters.
// - findDuplicatesHash(char *): Finds duplicates using a hash table.
// - findDuplicatesBits(char *): Finds duplicates using bit manipulation.
//
// ════════════════════════════════════════════════════════════════════

void findDuplicatesComparingAll(char *);
void findDuplicatesHash(char *);
void findDuplicatesBits(char *);

int main() {

    char str[] = "anaerobicoa";

    // findDuplicatesComparingAll(str);
    // findDuplicatesHash(str);
    findDuplicatesBits(str);

    return 0;
}

void findDuplicatesComparingAll(char *str) {

    for (int i = 0; str[i] != '\0'; i++) {

        if (str[i] < 'a' || str[i] > 'z' || str[i] == -1) {
            continue;
        }

        for (int j = i + 1; str[j] != '\0'; j++) {
            if (str[i] == str[j]) {
                printf("Duplicate found: %c\n", str[i]);
                str[j] = -1;
            }
        }
    }

}

void findDuplicatesHash(char *str) {
    int hash[256] = {0};

    for (int i = 0; str[i] != '\0'; i++) {
        hash[(unsigned char)str[i]]++;
    }

    for (int i = 0; i < 256; i++) {
        if (hash[i] > 1) {
            printf("Duplicate found: %c\n", i);
        }
    }
}

void findDuplicatesBits(char *str) {
    int seen = 0;
    int reported = 0;

    for (int i = 0; str[i] != '\0'; i++) {

        char c = tolower(str[i]);

        if (c < 'a' || c > 'z') continue;

        int bit = 1 << (c - 'a');

        if (seen & bit) {
            if (!(reported & bit)) {
                printf("Duplicate found: %c\n", c);
                reported |= bit;
            }
        } else {
            seen |= bit;
        }
    }
}