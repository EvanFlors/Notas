#include <stdio.h>
#include <stdlib.h>

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