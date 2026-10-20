# Starter — tf-01-02-why-do-we-need-state

Esta actividad es **conceptual** (sin código). El "starter" es solo esta nota.

## Qué hacer

1. Crear el directorio de trabajo:

   ```bash
   mkdir -p /tmp/tf-01-state
   cd /tmp/tf-01-state
   ```

2. Crear `WRITEUP.md` siguiendo las secciones A, B, C, D y las 7 preguntas descritas en `../README.md`.

3. Validar estructura:

   ```bash
   bash ../tests/validate.sh /tmp/tf-01-state
   ```

4. Autocomparar con `../solution/WRITEUP-reference.md`.

## Plantilla sugerida

Puedes copiar esto como punto de partida en `/tmp/tf-01-state/WRITEUP.md`:

```markdown
# WRITEUP — tf-01: Por qué el state es necesario

## A. Tres razones por las que el state es necesario

1. Mapeo HCL ↔ IDs reales: ...
2. Atributos computados (ejemplos): ...
3. Falta de listado barato/preciso en las APIs: ...

## B. Experimento mental "Terraform stateless"

(4–6 frases)

## C. Drift y por qué `apply` por sí solo no lo detecta todo

(5–8 frases)

## D. Consecuencias operativas del state

- No va a Git porque ...
- Debe vivir en backend remoto porque ...
- Debe tener locking porque ...
- Debe estar encriptado at-rest porque ...

## Preguntas

1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```
