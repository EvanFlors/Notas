# Actividad 01 — Jerarquía: environment secret vs repo secret

## 1. Identificación

- **ID:** `gha-05-01-env-vs-repo-secret`
- **Tecnología:** `github-actions`
- **Módulo:** `05-secrets-variables-and-environments-basics`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Una aplicación se despliega a **dos entornos**: `staging` y `production`. Comparten *forma* de configuración (todos tienen `API_URL`, `API_TOKEN`, `FEATURE_FLAGS`) pero con **valores distintos**. Hay además un valor común a toda la organización: `TELEMETRY_URL`, idéntico en todos los repos.

Esta actividad te hace diseñar y escribir en YAML esa jerarquía: qué va como `secret`, qué va como `var`, en qué scope (repo, environment, u org), y cómo luce el workflow que lo consume.

Como la actividad trata de **estructura del YAML y referencias correctas**, podés validarla **localmente sin ejecutar el workflow en GitHub**. El validador parsea los YAMLs y verifica que:

- Existen los dos workflows pedidos.
- Usan la sintaxis correcta `${{ secrets.X }}` / `${{ vars.Y }}`.
- Referencian los nombres estándar de este ejercicio.
- Los dos jobs de deploy difieren solo en `environment:` (prueba de que la variación se mueve del YAML a GitHub).
- Hay `permissions:` top-level declaradas.

Hay un **modo `live`** opcional (`MODE=live`) para cuando quieras subirlo a un repo real y comprobar que efectivamente los environments resuelven valores distintos.

## 3. Objetivos

- Decidir, dado un conjunto de datos, qué es `secret` y qué es `var`, y a qué scope va cada uno.
- Escribir dos workflows mínimos que referencian secretos y vars respetando esa jerarquía.
- Dejar que la *configuración por entorno* viva en GitHub (environments), no en el YAML.
- Validar la estructura localmente con `tests/validate.sh`.

## 4. Prerrequisitos

- `gha-02` (sintaxis y contextos).
- Lectura de `theory/lesson.md` de este módulo.
- Bash + `grep`/`awk`. **Opcional**: `yq` o `python3` con PyYAML si querés inspeccionar YAML con más gusto; el validador no los requiere.
- Modo `live` (opcional): repo propio con permiso para crear environments y secretos.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha-05-env-vs-repo-secret
```

Esto crea una carpeta de trabajo en `/tmp/gha-05-env-vs-repo-secret/local/` con:

- `.github/workflows/placeholder.yml` — plantilla que vas a reemplazar.
- `TASK.md` — el enunciado detallado, idéntico al de abajo.

### 5.2 El escenario (resuelve esto antes de abrir YAML)

Datos a manejar:

| Nombre lógico | ¿Sensible? | ¿Difiere por entorno? | ¿Compartido con otros repos? |
|---|---|---|---|
| `API_URL` | No (es una URL pública de la propia infra) | Sí (staging ≠ prod) | No |
| `API_TOKEN` | Sí | Sí (staging ≠ prod) | No |
| `FEATURE_FLAGS` | No | Sí | No |
| `TELEMETRY_URL` | No | No | Sí |

Decidí para cada uno:

- `secret` o `var`.
- Scope: repo, environment, u organización.

(Respuesta esperada: ver sección 6; **no la mires antes de intentarlo**.)

### 5.3 Escribir los workflows

Creá **dos archivos** dentro de `/tmp/gha-05-env-vs-repo-secret/local/.github/workflows/`:

1. `deploy.yml` — Un workflow con **dos jobs** (`deploy-staging`, `deploy-prod`) que:
   - Declaran `permissions: contents: read` a nivel top-level.
   - Cada job declara su `environment:` correspondiente.
   - Ambos jobs leen las mismas keys (`API_URL`, `API_TOKEN`, `FEATURE_FLAGS`, `TELEMETRY_URL`) via `env:` mapeando con la sintaxis correcta.
   - Un step `print-config` imprime los valores no sensibles (var) y el valor del secreto (que debe terminar enmascarado en `***` cuando corra de verdad).

2. `smoke.yml` — Un workflow sin `environment:` que lee **solo** `TELEMETRY_URL` como var (porque es org-scoped y vale igual en todas partes) y hace un `echo` con ella. Sirve para demostrar que una variable org-level se resuelve sin environment.

Guía mínima de forma:

```yaml
# deploy.yml (fragmento esperado)
name: deploy
on: { workflow_dispatch: {} }

permissions:
  contents: read

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    env:
      API_URL:        ${{ vars.API_URL }}
      API_TOKEN:      ${{ secrets.API_TOKEN }}
      FEATURE_FLAGS:  ${{ vars.FEATURE_FLAGS }}
      TELEMETRY_URL:  ${{ vars.TELEMETRY_URL }}
    steps:
      - name: print-config
        run: |
          echo "env=staging"
          echo "API_URL=$API_URL"
          echo "FEATURE_FLAGS=$FEATURE_FLAGS"
          echo "TELEMETRY_URL=$TELEMETRY_URL"
          echo "API_TOKEN=$API_TOKEN"   # saldrá como ***

  deploy-prod:
    # ... idéntico salvo environment: production
```

### 5.4 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha-05-env-vs-repo-secret
```

Debe terminar en `RESULT (local): N/N checks OK.`.

### 5.5 Modo `live` (opcional)

1. Creá un repo tuyo (puede ser privado).
2. Copiá los dos workflows a `.github/workflows/` del repo.
3. En Settings → Environments: creá `staging` y `production`. En cada uno:
   - Variable `API_URL` con un valor distinto (p. ej. `https://api.staging.local` vs `https://api.prod.local`).
   - Variable `FEATURE_FLAGS` con un valor distinto (p. ej. `beta=true` vs `beta=false`).
   - Secret `API_TOKEN` con un string de prueba (ponelos distintos para notar el masking).
4. En Settings → Secrets and variables → Actions → Variables: creá `TELEMETRY_URL` a nivel repo (si fuera de verdad org-wide, iría a nivel organización; para el ejercicio alcanza con repo).
5. Actions → "deploy" → Run workflow. Confirmá:
   - `API_URL` sale distinto en cada job.
   - `API_TOKEN` sale como `***`.
   - `TELEMETRY_URL` sale idéntica en ambos jobs.
6. `MODE=live bash tests/validate.sh` corre los mismos checks estructurales del YAML (no toca GitHub; para esta actividad no hay nada que verificar vía API más allá del YAML en sí).

## 6. Resultado esperado

**Diseño correcto (lo que el validador asume que escribiste):**

| Dato | Tipo | Scope |
|---|---|---|
| `API_URL` | `var` | environment (`staging`, `production`) |
| `API_TOKEN` | `secret` | environment (`staging`, `production`) |
| `FEATURE_FLAGS` | `var` | environment (`staging`, `production`) |
| `TELEMETRY_URL` | `var` | repo (en un setup real: organización) |

**Workflows:**

- `deploy.yml` con `permissions: contents: read` top-level y dos jobs `deploy-staging` / `deploy-prod` que difieren **solo** en `environment:`.
- `smoke.yml` sin `environment:` que referencia solo `${{ vars.TELEMETRY_URL }}`.

## 7. Criterios de aceptación

- [ ] `deploy.yml` existe y tiene `permissions:` top-level con `contents: read`.
- [ ] `deploy.yml` tiene **dos jobs** con `environment: staging` y `environment: production`.
- [ ] Ambos jobs mapean `API_TOKEN` como `${{ secrets.API_TOKEN }}` (no como `vars`).
- [ ] Ambos jobs mapean `API_URL`, `FEATURE_FLAGS`, `TELEMETRY_URL` como `${{ vars.X }}` (no como `secrets`).
- [ ] `smoke.yml` existe, no declara `environment:` y referencia `${{ vars.TELEMETRY_URL }}`.
- [ ] `smoke.yml` NO referencia `API_TOKEN`.
- [ ] `tests/validate.sh` termina con exit 0 en `MODE=local`.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha-05-env-vs-repo-secret
```

El validador:

- Comprueba que ambos archivos YAML existan en la ruta esperada.
- Hace parsing con `python3 -c "import yaml"` para asegurar YAML válido.
- Grep de patrones clave (presencia de `permissions:`, `environment:`, uso correcto de `secrets.` vs `vars.`).
- Confirma que `smoke.yml` no referencia secretos.

## 9. Preguntas de reflexión

1. ¿Por qué `API_URL` va como `var` y no como `secret`? ¿Qué cambiarías si la URL expusiera un host privado detrás de VPN?
2. ¿Por qué el mismo nombre `API_TOKEN` puede tener dos valores sin que el workflow lo sepa?
3. ¿Qué pasaría si `TELEMETRY_URL` solo existiera como variable en un environment y el workflow `smoke.yml` no declara ninguno?
4. ¿Qué ventaja tiene subirla a scope **organización** en vez de repo si tenés 30 repos que la usan?
5. En `MODE=live`, si entrás al log del step `print-config` y copiás el `***` del `API_TOKEN`, ¿tenés el valor real? ¿Por qué?

## 10. Extensiones

- **E1** — Añadí un tercer environment `dev` sin cambiar el YAML: solo creás el environment en GitHub y agregás un job `deploy-dev` que apunta a él.
- **E2** — Modificá `deploy.yml` para que *un solo* job matricial (`strategy.matrix.environment: [staging, production]`) reemplace los dos jobs duplicados. Comentá qué se pierde (claridad del log, cada entorno visible como job separado).
- **E3** — Hacé que `smoke.yml` falle con un mensaje claro si `TELEMETRY_URL` no está definida (expresión + `if:`).

## 11. Limpieza

```bash
rm -rf /tmp/gha-05-env-vs-repo-secret
# Modo live: borrá los environments o el repo entero si lo creaste para la práctica.
```
