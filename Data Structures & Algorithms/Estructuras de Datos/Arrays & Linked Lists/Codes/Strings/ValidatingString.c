#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Validate a string (alphanumeric characters only)
//
// Given: A string
// Returns: 1 if the string is valid (contains only letters and digits), 0
//
// Method 1: Iteration      - O(n), O(1) space
//
// ════════════════════════════════════════════════════════════════════

int validateString(const char *);

int main() {

    const char *testString = "Hello123";

    if (validateString(testString)) {
        printf("Valid string.\n");
    } else {
        printf("Invalid string.\n");
    }

    return 0;
}

int validateString(const char *str) {

    for(int i = 0; str[i] != '\0'; i++) {
        char c = str[i];
        if (
            !(c >= 65 && c <= 90) &&
            !(c >= 97 && c <= 122) &&
            !(c >= 48 && c <= 57)
        ) {
            return 0;
        }
    }

    return 1;
}