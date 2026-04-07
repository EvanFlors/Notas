#include <stdio.h>
#include <stdlib.h>

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