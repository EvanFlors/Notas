#include <stdio.h>
#include <stdlib.h>

// ═════════════════════════════════════════════════════════════════════════════
//
// Generate all permutations of a string
//
// Given: A string
// Returns: All permutations of the string
//
// Method 1: Backtracking with a frequency array    - O(n! * n) time, O(n) space
// Method 2: Backtracking with swapping             - O(n! * n) time, O
//
// ═════════════════════════════════════════════════════════════════════════════


void permutations(char [], int);
void permutationsWithSwap(char [], int, int);
void swap(char *, char *);

int main() {

    char s[] = "ABC";
    permutations(s, 0);
    permutationsWithSwap(s, 0, 2);

    return 0;
}

void permutations(char s[], int k) {
    static int A[256] = {0};
    static char result[256];
    int i = 0;

    if (s[k] == '\0') {
        result[k] = '\0';
        printf("%s\n", result);
        return;
    }

    for (i = 0; s[i] != '\0'; i++) {
        if (A[i] == 0) {
            result[k] = s[i];
            A[i]++;
            permutations(s, k + 1);
            A[i]--;
        }
    }
}

void swap(char *a, char *b) {
    char temp = *a;
    *a = *b;
    *b = temp;
}

void permutationsWithSwap(char s[], int l, int h) {

    int i;

    if (l == h) {
        printf("%s\n", s);
        return;
    }

    for (i = l; i <= h; i++) {
        swap(&s[l], &s[i]);
        permutationsWithSwap(s, l + 1, h);
        swap(&s[l], &s[i]);
    }

}