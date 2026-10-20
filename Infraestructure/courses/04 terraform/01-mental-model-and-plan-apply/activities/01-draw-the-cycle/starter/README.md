# Starter — tf-01-01-draw-the-cycle

Esta actividad es **conceptual** (sin código). El "starter" es solo esta nota.

## Qué hacer

1. Crear el directorio de trabajo:

   ```bash
   mkdir -p /tmp/tf-01-cycle
   cd /tmp/tf-01-cycle
   ```

2. Crear `MAP.md` siguiendo las secciones A, B, C, D y las 7 preguntas descritas en `../README.md`.

3. Validar estructura:

   ```bash
   bash ../tests/validate.sh /tmp/tf-01-cycle
   ```

4. Autocomparar con `../solution/MAP-reference.md`.

## Plantilla sugerida

Puedes copiar esto como punto de partida en `/tmp/tf-01-cycle/MAP.md`:

```markdown
# MAP — tf-01: Ciclo init → plan → apply → destroy

## A. Los tres estados

(diagrama ASCII con: estado deseado | state | infra real)

- Estado deseado: ...
- State: ...
- Infra real: ...

## B. El ciclo init → plan → apply → destroy

(diagrama ASCII)

- init: qué hace, qué toca, qué NO toca
- plan: qué hace, qué toca, qué NO toca (incluir refresh)
- apply: qué hace, qué toca, qué NO toca
- destroy: qué hace, qué toca, qué NO toca

## C. Los símbolos del plan

- `+` : ...
- `-` : ...
- `~` : ...
- `-/+` : ...
- `<=` : ...

## D. Idempotencia y drift

- Idempotencia en Terraform: ...
- Drift: ...

## Preguntas

1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```
