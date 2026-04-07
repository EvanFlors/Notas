#include <stdio.h>
#include <stdlib.h>

void reverseString(char *);

int main() {

    char testString[] = "Hello, World!";
    printf("Original: %s\n", testString);

    reverseString(testString);
    printf("Reversed: %s\n", testString);

    return 0;
}

void reverseString(char *str) {

    int len = 0, i, j;
    char tmp;

    while (str[len] != '\0') {
        len++;
    }

    for (i = 0, j = len - 1; i < j; i++, j--) {
        tmp = str[i];
        str[i] = str[j];
        str[j] = tmp;
    }
}