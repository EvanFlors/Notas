# Starter — ans-05-02-collection-eval-adr

Esta actividad es **independiente**: produces un único archivo Markdown.

## Pasos

1. Lee `../README.md` completo y la lección (§5, §8, §9).
2. Recorre `../../examples/03-automation-hub-walkthrough/`.
3. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-05-02
   cd /tmp/ans-05-02
   ```
4. Escribe `ADR-COLLECTION-ADOPTION.md` con las 6 secciones del formato ADR y el contenido mínimo descrito en `../README.md` §5.3.
5. Verifica:
   ```bash
   bash <ruta-repo>/courses/ansible/05-collections-galaxy-and-automation-hub/activities/02-collection-eval-adr/tests/validate.sh /tmp/ans-05-02
   ```
6. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueleto útil

```markdown
# ADR 002 — Adopcion de collections AWS

## Estado
Aceptado

## Contexto
...

## Decision
...

| Criterio | amazon.aws | community.aws |
|----------|------------|---------------|
| Mantenimiento | ... | ... |
| Cobertura | ... | ... |
| Dependencias upstream | ... | ... |
| Licencia | ... | ... |
| Certificada | si | no |
| Namespace/propietario | ... | ... |

## Consecuencias
...

## Alternativas descartadas

### Alternativa 1 — Usar solo community.aws
...

### Alternativa 2 — Escribir modulos propios
...
```

> El validador comprueba estructura y presencia de palabras clave, **no** semántica.
