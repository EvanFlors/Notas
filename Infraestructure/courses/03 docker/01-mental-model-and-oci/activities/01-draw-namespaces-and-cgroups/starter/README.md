# Starter — dkr-01-01-draw-namespaces-and-cgroups

Esta actividad es **conceptual** (sin código). El "starter" es solo esta nota.

## Qué hacer

1. Crear el directorio de trabajo:

   ```bash
   mkdir -p /tmp/dkr-01-mental-model
   cd /tmp/dkr-01-mental-model
   ```

2. Crear `MAP.md` siguiendo las secciones A, B, C, D y las 7 preguntas descritas en `../README.md`.

3. Validar estructura:

   ```bash
   bash ../tests/validate.sh /tmp/dkr-01-mental-model
   ```

4. Autocomparar con `../solution/MAP-reference.md`.

## Plantilla sugerida

Puedes copiar esto como punto de partida en `/tmp/dkr-01-mental-model/MAP.md`:

```markdown
# MAP — dkr-01: Namespaces, cgroups y pila Docker→runc

## A. Namespaces de Linux

| Namespace | Qué aisla | Antes vs después |
|-----------|-----------|------------------|
| pid       |           |                  |
| mnt       |           |                  |
| net       |           |                  |
| user      |           |                  |
| uts       |           |                  |
| ipc       |           |                  |
| cgroup    |           |                  |

Nota sobre user namespace en Docker: ...

## B. Controladores de cgroups v2

- cpu: ...
- memory: ...
- pids: ...
- io: ...

## C. Pila Docker → runc

(diagrama ASCII + descripción por eslabón)

## D. Por qué OCI permite intercambiar runtimes

(3–5 frases nombrando image-spec, runtime-spec, distribution-spec)

## Preguntas

1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```
