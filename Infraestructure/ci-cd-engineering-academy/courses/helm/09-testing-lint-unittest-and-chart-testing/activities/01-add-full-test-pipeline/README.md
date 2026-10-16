# Actividad 01 — Añade un pipeline completo de testing a un chart

## 1. Identificación

- **ID:** `helm-09-01-add-full-test-pipeline`
- **Tecnología:** `helm`
- **Módulo:** `helm-09-testing-lint-unittest-and-chart-testing`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes un chart `demo-app` básico y necesitas convertirlo en algo que puedas publicar con confianza. Vas a añadir las **4 capas** de validación discutidas en la lección y conectarlas en un workflow de GitHub Actions. El entregable final es un repo (o directorio) donde cada PR a `main` corre:

1. `helm lint --strict`
2. `helm template` (dry render) sobre `values.yaml` y variantes.
3. `helm unittest`.
4. `ct install` sobre una matriz de **al menos 2 versiones** de Kubernetes.

Es la misma pipeline que usarías para un chart de verdad.

## 3. Objetivos

Al terminar deberías poder:

- Añadir `tests/*_test.yaml` de `helm-unittest` a un chart.
- Escribir un `ct.yaml` razonable para `chart-testing`.
- Escribir un workflow `.github/workflows/chart-ci.yaml` con **4 jobs** encadenados y matriz en el job `install`.
- Documentar en el `README.md` del chart la **matriz de versiones de K8s** y justificar la elección.

## 4. Prerrequisitos

- `helm` ≥ 3.14 (si está disponible — la actividad hace SKIP graceful si falta).
- Plugin `helm-unittest` (`helm plugin install https://github.com/helm-unittest/helm-unittest`).
- `ct` (chart-testing) si quieres correr `ct install` localmente (opcional — el workflow lo instala en CI).
- `kind` + `docker` si quieres probar `ct install` localmente (opcional).
- `git` + cuenta GitHub (solo para publicar el workflow; no necesario para que valide la estructura).

**Costos**: cero. Todo local o GitHub Actions free tier.

## 5. Instrucciones

### 5.1 Prepara el directorio de trabajo

```bash
rm -rf /tmp/helm-09-01
mkdir -p /tmp/helm-09-01
cp -r starter/* /tmp/helm-09-01/
cd /tmp/helm-09-01
```

El `starter/` incluye:

```
starter/
├── charts/demo-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/{deployment.yaml, service.yaml}
└── README-TODO.md   ← guía con los pasos
```

### 5.2 Capa 1 — `helm lint`

```bash
helm lint --strict charts/demo-app
```

Si falla, arregla antes de seguir. Añade un comentario `# lint: ok` al final de `README-TODO.md`.

### 5.3 Capa 2 — `helm template`

```bash
helm template rel charts/demo-app --debug > /tmp/render.yaml
head /tmp/render.yaml
```

Confirma que el output es YAML válido.

### 5.4 Capa 3 — `helm unittest`

Crea `charts/demo-app/tests/deployment_test.yaml` con al menos **3 tests** (default, override, un edge case). Base de arranque:

```yaml
suite: deployment
templates:
  - deployment.yaml
tests:
  - it: default replica count
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: spec.replicas
          value: 1
```

Corre:

```bash
helm unittest charts/demo-app
```

### 5.5 Capa 4 — `ct.yaml`

Crea `ct.yaml` en el root:

```yaml
chart-dirs:
  - charts
target-branch: main
check-version-increment: true
helm-extra-args: --timeout 600s
```

### 5.6 Workflow de GitHub Actions

Crea `.github/workflows/chart-ci.yaml` con 3 jobs: `lint`, `unittest`, `install`. El job `install` usa `strategy.matrix.k8s` con **al menos 2 versiones** (p. ej. `v1.31.0` y `v1.30.0`) y usa `helm/kind-action@v1` + `helm/chart-testing-action@v2`.

Base de referencia en `examples/01-ct-workflow/.github/workflows/chart-ci.yaml`.

### 5.7 Documenta la matriz

En `README.md` del chart (`charts/demo-app/README.md`), añade una sección `## Supported Kubernetes versions` con la lista de versiones y **1–2 párrafos justificando la elección** (política *n, n-1*, cliente obliga a 1.29, etc.).

### 5.8 Validar estructura

```bash
bash tests/validate.sh /tmp/helm-09-01
```

El validador comprueba estructura (no corre `ct install`): existencia de workflow con los 4 steps clave, `ct.yaml`, `tests/*_test.yaml`, y la sección `## Supported Kubernetes versions`.

## 6. Resultado esperado

- `/tmp/helm-09-01/ct.yaml` existe.
- `/tmp/helm-09-01/.github/workflows/chart-ci.yaml` existe con 3 jobs y matriz de ≥ 2 versiones.
- `/tmp/helm-09-01/charts/demo-app/tests/` contiene al menos un `*_test.yaml` con ≥ 3 tests.
- `/tmp/helm-09-01/charts/demo-app/README.md` incluye `## Supported Kubernetes versions`.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] `helm lint --strict charts/demo-app` sale en 0 (si tienes `helm`).
- [ ] `helm template` renderiza sin error.
- [ ] `helm unittest` corre en verde (si tienes el plugin).
- [ ] Workflow tiene los 3 jobs (`lint`, `unittest`, `install`) y el job `install` tiene matriz.
- [ ] `ct.yaml` tiene `chart-dirs` y `target-branch`.
- [ ] `README.md` del chart documenta la matriz con justificación.

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm-09-01
```

Estructural. **Semántica la calibras tú** con `solution/`.

## 9. Preguntas de reflexión

1. ¿Por qué el job `install` depende de `lint` y `unittest` y no al revés?
2. Si tu equipo solo soporta un cluster EKS 1.30, ¿qué pierdes y qué ganas con una matriz de 3 vs 1?
3. ¿Por qué `fetch-depth: 0` es importante en el job que corre `ct`?
4. Un PR que solo toca `README.md` del chart, ¿debe gatillar `ct install`? ¿Cómo lo evitas?

## 10. Extensiones

- **E1** — Añade un step de `helm template --debug` que **comente el PR** con el diff vs `main` (busca `actions/github-script` o acciones existentes).
- **E2** — Añade un snapshot test al chart y commitea el `.snap` resultante.
- **E3** — Añade una tercera versión de K8s a la matriz y mide cuánto subió el tiempo total del pipeline.

## 11. Limpieza

```bash
rm -rf /tmp/helm-09-01
# Si creaste cluster kind local:
# kind delete clusters --all
```
