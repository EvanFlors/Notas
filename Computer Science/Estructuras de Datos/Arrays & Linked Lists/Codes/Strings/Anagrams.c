#include <stdio.h>
#include <stdlib.h>

// ════════════════════════════════════════════════════════════════════
//
// Check if two strings are anagrams of each other. An anagram is a word or
// phrase formed by rearranging the letters of a different word or phrase,
// typically using all the original letters exactly once.
//
// Given: Two strings
// Returns: 1 if they are anagrams, 0 otherwise
//
// Method 1: Iteration      - O(n), O(1) space
//
// ════════════════════════════════════════════════════════════════════

int areAnagrams(char *, char *);

int main() {

    char A[] = "listen";
    char B[] = "silent";

    if (areAnagrams(A, B)) {
        printf("'%s' and '%s' are anagrams.\n", A, B);
    } else {
        printf("'%s' and '%s' are not anagrams.\n", A, B);
    }

    return 0;
}

int areAnagrams(char *str1, char *str2) {
    int count[256] = {0};

    for (int i = 0; str1[i] && str2[i]; i++) {
        count[(unsigned char)str1[i]]++;
        count[(unsigned char)str2[i]]--;
    }

    for (int i = 0; i < 256; i++) {
        if (count[i] != 0) return 0;
    }

    return 1;

}