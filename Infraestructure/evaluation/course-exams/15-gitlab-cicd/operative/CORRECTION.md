# Guía de corrección — Sección B (operativa)

**Solo para el instructor.** No compartir con candidatos antes del examen.

## Flujo recomendado

1. Ejecutar `./validate.sh ../entrega` y capturar la salida.
2. Para cada `FAIL`, abrir el YAML y confirmar manualmente (el script es `grep` estructural, no entiende semántica).
3. Para cada **RED FLAG** detectada: reducir la sección a `Insuficiente` sin leer el resto.
4. Mapear a la rúbrica de `EXAM.md` § B.

## Mapeo check → rúbrica

| Check script | Criterio de rúbrica |
|---|---|
| 1a/1b/1c (parse) | Sintaxis YAML válida |
| 2 (stages) | Sintaxis YAML válida + stages |
| 3a/3b/3c | `workflow:` MR/main + bloqueo `[skip ci]` |
| 4 (PYTHON_IMAGE pin) | Image pinning (contribuye a «imagen sin `:latest`») |
| 5a/5b/5c | DAG con `needs:` |
| 6 | `parallel: matrix:` con sharding |
| 7 | OIDC/ID Token sin keys estáticas |
| 8a/8b/8c | Review App con `on_stop:` |
| 9 | Prod protegido (`when: manual`) |
| 10 | Scanners (≥3 include:template) |
| 11a/11b/11c | Reutilización (`include:local` + `extends` + Component) |

## Errores comunes y cómo puntuarlos

- **`needs:` como lista de todo lo anterior** («needs: [build, test_unit, test_lint]» en `package`): el DAG se vuelve lineal. `Básico (1)` en «DAG», aunque el script pase el check de `test_unit`.
- **`workflow:` que solo tiene `main`**: pipeline no corre en MRs. `Insuficiente` en workflow.
- **`id_tokens:` presente pero también `AWS_ACCESS_KEY_ID` en variables**: red flag + no cuenta como OIDC resuelto. Reduce la sección.
- **Scanners incluidos pero todos con `allow_failure: true`**: aceptar como `Básico (1)` en scanners; es la red flag «scanners desactivados de facto»  si se aplica a los 5+.
- **Component existe pero sin `spec: inputs:`**: no cumple el requisito 10 — `Básico (1)` en reutilización.
- **Review App sin `on_stop:` o sin `auto_stop_in:`**: red flag «Review App huérfana».
- **Candidato pega plantilla oficial sin cambiar nombres de jobs**: señal de copia; preguntar follow-up de `EXAM.md`.

## Señales de "respondió sin entender"

- Comentarios en español contradicen el YAML en inglés (p. ej. «no corre en MRs» pero `merge_request_event` está declarado).
- `rules:` que replica literalmente `only:` sin usar `$CI_PIPELINE_SOURCE` ni `$CI_MERGE_REQUEST_IID` (no entendió el modelo nuevo).
- `extends:` apunta a un job que no existe (copió de otro repo).
- Component declara `spec: inputs:` pero el consumidor no pasa ningún input.

## Puntaje final de la sección

- Convertir cada criterio de la rúbrica a `{0, 1, 2, 3}` × peso.
- Si la suma `>= 60 %` del máximo **y** no hay red flags → aprueba la sección.
- Si `< 60 %` o hay red flag → `Insuficiente` en operativa; la nota global rara vez supera 70 %.
