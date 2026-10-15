# Solución de referencia — k8s-13-02

El ADR es una **actividad independiente**: no hay una respuesta "correcta". El `solution/0001-autoscaler-choice.example.md` es **un** ejemplo plausible de ADR que elige Karpenter y satisface el validador. Léelo *después* de haber escrito el tuyo.

## Diferencias legítimas con tu ADR

- Puedes elegir CA modernizado y seguir siendo correcto si argumentas bien (p. ej. prioridad en portabilidad multi-cloud).
- Las dimensiones de la tabla y los valores son materia de criterio.
- Las referencias pueden ser otras (y mejores si son más recientes que las citadas aquí).

## Cómo validar

```bash
cp solution/0001-autoscaler-choice.example.md /tmp/k8s-13-02/docs/adr/0001-autoscaler-choice.md
bash tests/validate.sh
# Debería imprimir RESULT: OK — N/N checks passed.
```
