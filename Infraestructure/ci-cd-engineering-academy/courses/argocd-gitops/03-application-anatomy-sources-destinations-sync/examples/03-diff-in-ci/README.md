# Ejemplo 03 — `argocd app diff` como gate en CI

## Concepto que demuestra

Usar `argocd app diff` como preview determinista en un pipeline de CI, equivalente a `terraform plan` dentro de un PR. El job comenta en el PR qué cambiaría si se mergeara, y opcionalmente bloquea si detecta cambios destructivos.

## Contexto

Antes de mergear a `main` (y que Argo CD auto-sincronice), queremos ver:

1. ¿Qué recursos cambiarían?
2. ¿Alguno sería *destructivo* (delete, replace de un `StatefulSet`, cambio de PVC)?
3. ¿Hay algún cambio inesperado por una mala edición de values?

`argocd app diff --revision <PR_SHA>` resuelve esto sin aplicar nada.

## Prerrequisitos

- Conocimiento conceptual de `argocd app diff` (ver `theory/lesson.md` §10).
- Para ejecutar el workflow en real: Argo CD accesible desde el runner (API HTTPS), token de API (`argocd account generate-token`), y un repo con Applications gestionadas.
- Para el demo local: solo `bash`.

## Archivos

- `ci-diff.yml` — ejemplo de workflow GitHub Actions que corre `argocd app diff` en un PR.
- `local-diff.sh` — simulación local: imprime los comandos exactos que correría el CI, con validación básica de los flags. **No** se conecta a ningún Argo CD; es un dry-run didáctico.

## Ejecución (local)

```bash
cd courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/examples/03-diff-in-ci
bash local-diff.sh
```

## Ejecución (CI real, opcional)

1. Añade `ci-diff.yml` a `.github/workflows/` de tu repo de infra.
2. Configura secrets: `ARGOCD_SERVER`, `ARGOCD_AUTH_TOKEN`.
3. Abre un PR que modifique un path gestionado por una Application. El job comentará el diff.

## Resultado esperado

- `local-diff.sh` imprime los comandos CLI exactos, con el `--revision` apuntando al SHA del PR.
- Falla con mensaje claro si faltan variables de entorno simuladas.
- No requiere Argo CD real.

## Interpretación

Códigos de salida de `argocd app diff`:

- `0`: no hay diff — nada cambiaría.
- `1`: hay diff — algo cambiaría.
- `>1`: error (sin acceso, app inexistente, etc.).

Estrategias comunes en CI:

- **Soft gate**: `argocd app diff ... || true` + comentar en PR. Nunca bloquea; informa.
- **Hard gate en recursos sensibles**: parsear la salida; si menciona `PersistentVolumeClaim`, `StatefulSet` o un namespace `prod-*`, exigir aprobación extra.
- **Required review**: combinar con `CODEOWNERS` de la carpeta de la Application.

## Errores frecuentes

- **Confundir `--revision` con `targetRevision`**: `--revision` sobrescribe *solo para este diff*; la Application no cambia su configuración.
- **Correr sin `--server-side-generate`**: el render en el laptop puede diferir del que haría el `repo-server` (por versiones de Helm/Kustomize distintas). Mejor forzar server-side-generate.
- **No cachear credenciales de Argo CD**: cada job hace login nuevo — más llamadas, más riesgo de rate-limit si el cluster está detrás de OIDC.

## Limpieza

Este ejemplo no crea recursos. Nada que limpiar.
