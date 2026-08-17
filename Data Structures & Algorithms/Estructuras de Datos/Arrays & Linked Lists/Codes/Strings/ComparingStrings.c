#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Compare strings and find the first non-matching character
//
// Given: Two strings
// Returns: The ASCII difference between the first non-matching characters
//
// Method 1: Iteration      - O(n), O(1) space
//
// ════════════════════════════════════════════════════════════════════

int compareStrings(char *, char *);

int main() {

    char str1[] = "Painters";
    char str2[] = "Painter";

    if (compareStrings(str1, str2) == 0) {
        printf("Strings are equal\n");
    } else {
        if (compareStrings(str1, str2) < 0) {
            printf("String 1 is less than String 2\n");
        } else {
            printf("String 1 is greater than String 2\n");
        }
    }

    return 0;
}

int compareStrings(char *str1, char *str2) {

    int i = 0, j = 0;

    while (str1[i] != '\0' && str2[j] != '\0') {
        if (str1[i] != str2[j]) {
            return str1[i] - str2[j];
        }
        i++;
        j++;
    }
    return str1[i] - str2[j];
}