#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int countWords(const char *);
int countVowels(const char *);

int main() {

    const char *myString = "Hello, World!";
    int wordCount = countWords(myString);
    int vowelCount = countVowels(myString);

    printf("Number of words: %d\n", wordCount);
    printf("Number of vowels: %d\n", vowelCount);

    return 0;
}

int countWords(const char *str) {

    int count = 0;
    int inWord = 0;

    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == ' ' || str[i] == '\t' || str[i] == '\n') {
            inWord = 0;
        } else if (!inWord) {
            inWord = 1;
            count++;
        }
    }

    return count;

}

int countVowels(const char *str) {

    int count = 0;

    for (int i = 0; str[i] != '\0'; i++) {
        char c = str[i];
        if (
            c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u'
            || c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U'
        ) {
            count++;
        }
    }

    return count;

}