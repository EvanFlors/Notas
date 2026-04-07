#include <stdio.h>
#include <stdlib.h>

int getStringLength(const char *);

int main() {

    const char *myString = "Hello, World!";
    int length = getStringLength(myString);
    printf("Length of the string: %d\n", length);

    return 0;
}

int getStringLength(const char *str) {

    int length = 0;

    while (str[length] != '\0') {
        length++;
    }
    return length;
}