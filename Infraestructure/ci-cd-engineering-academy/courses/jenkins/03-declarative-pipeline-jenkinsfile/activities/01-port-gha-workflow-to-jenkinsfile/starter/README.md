# Starter — jk-03-01

El workflow origen (`.github/workflows/ci.yml`) es el input. Tu tarea es escribir el `Jenkinsfile` equivalente en `/tmp/jk-03-01/Jenkinsfile`.

## Mapeo sugerido GHA → Declarative

| GHA | Jenkins Declarative |
|-----|---------------------|
| `jobs:` | `stages { stage { ... } }` |
| `runs-on: ubuntu-latest` | `agent { label 'linux' }` o `agent any` |
| `container: node:20-alpine` | `agent { docker { image 'node:20-alpine' } }` |
| `env:` top-level | `environment { }` top-level |
| `secrets.GHCR_TOKEN` | `withCredentials([string(credentialsId: 'ghcr-token', variable: 'GHCR_TOKEN')]) { ... }` |
| `if: github.ref == 'refs/heads/main'` | `when { branch 'main' }` |
| `environment: production` con protection rule | `input message: '...' + timeout + submitter` (ver `jk-03-02`) |
| `actions/upload-artifact` | `archiveArtifacts` + `junit` en `post { always { ... } }` |
| `strategy.matrix` | `matrix { }` dentro de `stages` (opcional en esta actividad) |
| `needs: [a, b]` | orden implícito de los `stage` en el `stages { }` (son secuenciales por defecto) |

## Qué simplificar

- Reemplaza el `strategy.matrix.node-version: [18, 20]` por **un único** stage `Test` con Node 20. Comenta en el `Jenkinsfile` cómo lo expresarías con `matrix { }` si fuera necesario.
- No es obligatorio implementar `Deploy prod` en esta actividad; el gate manual se añade en `jk-03-02`. Pero sí debes implementar `Deploy staging` con el `when` correcto.

## Cómo validar

```bash
bash ../tests/validate.sh /tmp/jk-03-01
```

Esperado: `0 issue(s)`.
