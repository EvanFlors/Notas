#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Changing Case of a String
// This function changes the case of each character in a string.
//
// Given: A string
// Returns: A new string with each character's case changed
//
// Method 1: Iteration      - O(n), O(1) space
//
// ════════════════════════════════════════════════════════════════════

char *changeCase(const char *);

int main() {

    const char *myString = "Hello, World!";
    char *newString = changeCase(myString);
    printf("Changed case string: %s\n", newString);

    free(newString);
    return 0;
}

char *changeCase(const char *str) {

    int length = 0;

    while (str[length] != '\0') {
        length++;
    }

    char *newStr = malloc((length + 1) * sizeof(char));

    if (newStr == NULL) {
        printf("Memory allocation failed.\n");
        return NULL;
    }

    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] >= 'A' && str[i] <= 'Z') {
            newStr[i] = str[i] + ('a' - 'A');
        } else if (str[i] >= 'a' && str[i] <= 'z') {
            newStr[i] = str[i] - ('a' - 'A');
        } else {
            newStr[i] = str[i];
        }
    }
    newStr[length] = '\0';
    return newStr;
}
