#include <math.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int coef;
    int exp;
} Term;

typedef struct {
    int numTerms;
    Term *terms;
} Polynomial;

Polynomial *createPolynomial();
Polynomial *Add(Polynomial *p1, Polynomial *p2);
int Evaluate(Polynomial p, int x);
void Display(Polynomial p);

int main() {

    Polynomial *p1 = createPolynomial();
    Polynomial *p2 = createPolynomial();

    printf("Polynomial 1: ");
    Display(*p1);
    printf("Polynomial 2: ");
    Display(*p2);

    Polynomial *sum = Add(p1, p2);
    printf("Sum: ");
    Display(*sum);

    // Free allocated memory
    free(p1->terms);
    free(p1);
    free(p2->terms);
    free(p2);
    free(sum->terms);
    free(sum);

    return 0;
}

Polynomial *createPolynomial() {
    Polynomial *p = (Polynomial *)malloc(sizeof(Polynomial));

    printf("Enter number of non-zero terms: ");
    scanf("%d", &p->numTerms);
    p->terms = (Term *)malloc(p->numTerms * sizeof(Term));

    printf("Enter non-zero terms (coef exp):\n");

    for (int i = 0; i < p->numTerms; i++) {
        scanf("%d %d", &p->terms[i].coef, &p->terms[i].exp);
    }

    return p;
}

void Display(Polynomial p) {
    for (int i = 0; i < p.numTerms; i++) {
        printf("%dx^%d ", p.terms[i].coef, p.terms[i].exp);
        if (i < p.numTerms - 1) {
            printf("+ ");
        }
    }
    printf("\n");
}

Polynomial *Add(Polynomial *p1, Polynomial *p2) {
    Polynomial *result = (Polynomial *)malloc(sizeof(Polynomial));
    result->terms = (Term *)malloc((p1->numTerms + p2->numTerms) * sizeof(Term));
    result->numTerms = 0;

    int i = 0, j = 0;
    while (i < p1->numTerms && j < p2->numTerms) {
        if (p1->terms[i].exp > p2->terms[j].exp) {
            result->terms[result->numTerms++] = p1->terms[i++];
        } else if (p1->terms[i].exp < p2->terms[j].exp) {
            result->terms[result->numTerms++] = p2->terms[j++];
        } else {
            result->terms[result->numTerms++] = (Term){p1->terms[i].coef + p2->terms[j].coef, p1->terms[i].exp};
            i++;
            j++;
        }
    }

    // Append any remaining terms from either polynomial
    while (i < p1->numTerms) {
        result->terms[result->numTerms++] = p1->terms[i++];
    }
    while (j < p2->numTerms) {
        result->terms[result->numTerms++] = p2->terms[j++];
    }

    return result;
}

int Evaluate(Polynomial p, int x) {
    int result = 0;
    for (int i = 0; i < p.numTerms; i++) {
        result += p.terms[i].coef * pow(x, p.terms[i].exp);
    }
    return result;
}
