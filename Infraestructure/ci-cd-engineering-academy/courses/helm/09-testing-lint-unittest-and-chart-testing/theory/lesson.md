# Lección: Testing de charts Helm — lint, unittest y chart-testing

> **ID:** `helm-09-testing-lint-unittest-and-chart-testing` · **Nivel:** avanzado · **Duración:** 2 h
> **Prerrequisitos:** `helm-04-templating-deep`, `helm-06-dependencies-and-umbrella-charts`.

---

## 1. Introducción intuitiva

Tienes un chart funcional. Pasa `helm install` en tu laptop. Lo publicas. Al día siguiente alguien lo instala con `--set replicas=0`, o pasa `extraEnv: []`, o deja `ingress.hosts` sin definir, y el render produce YAML inválido (indentación rota, `null` donde debería haber una lista, un `Deployment` con `spec.replicas: null`). Peor: el YAML sí es válido, pero describe algo que el API server rechaza (`apiVersion` obsoleto, `nodeSelector` referenciando una label que no existe, un `PodSpec` cuyo probe falla antes del primer `ready`).

Nada de esto se atrapa con "yo probé el happy path". Son **edge cases de values** y **drift entre versiones de Kubernetes**. Son también los dos tipos de bug más caros: fallan en producción, en el cluster del cliente, y la primera señal es un `helm install` roto para alguien que no eres tú.

La solución es una **pirámide de testing para charts** con cuatro capas, cada una barata respecto a la siguiente y cubriendo bugs que la anterior no vería:

```
          ┌─────────────────────┐
          │  4. ct install      │  ← install real + helm test, matriz K8s, kind
          ├─────────────────────┤
          │  3. helm-unittest   │  ← asserts sobre manifests renderizados
          ├─────────────────────┤
          │  2. helm template   │  ← ¿rinde a YAML válido?
          ├─────────────────────┤
          │  1. helm lint       │  ← ¿tiene campos obligatorios? ¿estilo?
          └─────────────────────┘
```

Esta lección te enseña a construir las cuatro capas y a integrarlas en un workflow de GitHub Actions que corre en cada PR. Al terminar, un chart tuyo no se merge si rompe lint, no renderiza, un edge case de values falla el assert, o no instala en alguna versión soportada de Kubernetes.

---

## 2. Fundamentos: por qué cuatro capas

Cada capa atrapa una **clase distinta** de bug. Esto no es sobre-ingeniería; es sobre **separación de preocupaciones**:

- **`helm lint`** — campos obligatorios de `Chart.yaml`, convenciones de nombre, errores sintácticos triviales del template. Barato (milisegundos). Nunca ejecuta nada.
- **`helm template --debug`** — materializa el YAML renderizado. Si una expresión Go template referencia una value inexistente sin `default`, aparece. Si la indentación produce `null` donde debería haber lista, aparece. No valida *contra Kubernetes*, solo que el YAML es parseable.
- **`helm-unittest`** — renderiza con valores que **tú controlas** y aplica asserts (`equal`, `contains`, `isKind`, `matchSnapshot`). Cubre la **lógica** del chart: "con `autoscaling.enabled=true`, debe aparecer un `HorizontalPodAutoscaler`"; "con `replicas=0` el Deployment debe omitir el campo o fallar la validación".
- **`chart-testing` (`ct`)** — levanta un `kind` real, instala el chart, corre `helm test`, borra todo. Lo hace sobre una **matriz de versiones de Kubernetes**. Es la única capa que atrapa: deprecated APIs, admission webhooks que rechazan el manifest, images que no existen, probes mal configurados.

**La regla cruel**: la mayoría de bugs de un chart están en **edge cases de values**. Esos los atrapa `helm-unittest` sin cluster. Pero el bug que te va a doler más —"se instala bien en 1.29 pero rompe en 1.31 porque `PodSecurityPolicy` desapareció"— solo lo atrapa `ct install` en matriz.

---

## 3. `helm lint`: la primera trinchera

`helm lint` corre dos cosas:

1. **Chart linter** — comprueba `Chart.yaml` (campos requeridos: `apiVersion`, `name`, `version`), presencia de `README.md`, `values.yaml`, convenciones (`appVersion` presente, nombre válido para release).
2. **Template linter** — renderiza con los defaults y comprueba que el YAML es parseable.

Severidades:

- `[INFO]` — convención (no bloquea).
- `[WARNING]` — algo sospechoso pero no fatal.
- `[ERROR]` — detiene el lint con exit code ≠ 0.

Modo **estricto**: `helm lint --strict` promueve WARNINGs a ERRORs. En CI usa `--strict` o estarás ignorando señales reales.

Ejemplo típico de uso en CI:

```bash
helm lint --strict ./charts/myapp
helm lint --strict ./charts/myapp -f values-prod.yaml
helm lint --strict ./charts/myapp -f values-dev.yaml
```

**No es suficiente**: `helm lint` pasa con un chart que renderiza `kind: Deployent` (sic). Solo valida que es YAML, no que sea Kubernetes válido. De ahí la capa 2.

---

## 4. `helm template --debug`: render diferencial

`helm template` renderiza el chart a stdout sin tocar un cluster. Con `--debug`, incluye los valores efectivos como comentarios y vuelca más contexto si falla. Es **la herramienta de diagnóstico #1** cuando algo no cuadra.

Dos usos operativos:

### 4.1 Validar que todos los value-files renderizan

```bash
for f in values.yaml values-dev.yaml values-stg.yaml values-prod.yaml; do
  helm template release-name ./charts/myapp -f "$f" > "/tmp/render-$f.yaml" || exit 1
done
```

### 4.2 Diff en PR

En un PR que cambia el chart, generas el render en `main` y en el branch, y haces `diff` de ambos. Esto hace **visible al revisor** qué va a cambiar el PR en los manifests finales — mucho más útil que ver un `_helpers.tpl` modificado y adivinar.

```bash
# en el branch
helm template rel ./charts/myapp -f values-prod.yaml > /tmp/new.yaml
git checkout main
helm template rel ./charts/myapp -f values-prod.yaml > /tmp/old.yaml
diff -u /tmp/old.yaml /tmp/new.yaml
```

Hay actions comunitarias (`helm-diff` plugin, `helm-diff-action`) que lo pegan como comentario del PR. Es un patrón barato con enorme retorno en seguridad del merge.

---

## 5. `helm-unittest`: asserts sobre renders

**`helm-unittest`** es un **plugin** de Helm:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
```

Añade el subcomando `helm unittest <chart>`. Busca archivos de test en `<chart>/tests/*_test.yaml` por default. Un *test suite* describe:

- `templates:` qué template(s) del chart renderizar.
- `tests:` lista de casos. Cada caso tiene `it:` (nombre), `set:` (values a aplicar), `asserts:` (lista de asserts).

### 5.1 Esqueleto mínimo

```yaml
# charts/demo-app/tests/deployment_test.yaml
suite: deployment
templates:
  - deployment.yaml
tests:
  - it: renders a Deployment with the default replica count
    asserts:
      - isKind:
          of: Deployment
      - equal:
          path: spec.replicas
          value: 1
```

### 5.2 Asserts principales

| Assert | Qué comprueba |
|---|---|
| `equal` / `notEqual` | Valor exacto en un `path:` JSONPath-like |
| `contains` / `notContains` | Elemento presente en una lista en `path:` |
| `isKind` | El `kind:` del documento renderizado |
| `isNull` / `isNotNull` | Campo nulo o presente |
| `exists` / `notExists` | Path presente/ausente |
| `matchRegex` | Regex sobre un string |
| `hasDocuments` | Número de docs renderizados |
| `failedTemplate` | Que el render falla con un error esperado (p. ej. `required`) |
| `matchSnapshot` | Igualdad contra snapshot grabado |

### 5.3 Edge cases que importan

Los bugs reales que `unittest` atrapa son:

1. **Default values** — "sin pasar nada, debe renderizar replicas=1 y la service port 80".
2. **Override completo** — "con `image.repository=foo` el `image:` sale como `foo:defaultTag`".
3. **Lista vacía** — "con `extraEnv: []`, el campo `env:` no aparece (o aparece vacío sin romper indentación)".
4. **Nil** — "con `ingress.hosts: null`, el `Ingress` no se renderiza o `required` falla con mensaje legible".
5. **Flag booleano** — "con `autoscaling.enabled=true`, aparece el `HorizontalPodAutoscaler`; con `false`, no aparece".

El patrón de `set:` suele ser:

```yaml
tests:
  - it: with empty extraEnv list, env field is absent
    set:
      extraEnv: []
    asserts:
      - notExists:
          path: spec.template.spec.containers[0].env
```

### 5.4 Internals (por qué es rápido)

`helm-unittest` corre `helm template` *en proceso* contra un chart leído del disco, luego parsea los documentos YAML resultantes y aplica cada assert contra el path indicado. **No habla con Kubernetes**. Un suite de 50 tests tarda segundos; se puede correr en pre-commit si quieres.

---

## 6. Patrón snapshot testing

A veces el chart renderiza algo "complejo" (un `Deployment` con sidecars, probes, resources, labels) y lo que quieres asegurar es que **ese output exacto no cambie accidentalmente**. Para eso sirve `matchSnapshot`.

Primera vez:

```yaml
tests:
  - it: Deployment snapshot
    asserts:
      - matchSnapshot: {}
```

`helm unittest` graba el render en `tests/__snapshot__/<suite>_test.yaml.snap`. En runs sucesivos, compara el render actual contra el snapshot. Si difieren, el test falla con un diff.

Para actualizar snapshots (sabiendo lo que haces):

```bash
helm unittest -u ./charts/demo-app
```

**Cuándo SÍ usar snapshots**:
- Templates que casi nunca deberían cambiar (manifests "canónicos").
- `_helpers.tpl` que genera labels estándar — un diff accidental grita fuerte.

**Cuándo NO**:
- Templates muy dinámicos (muchas values rellenan muchos campos) — los snapshots se desactualizan cada PR y la gente los actualiza sin leer. **Un snapshot que siempre se actualiza no está testeando nada.**

Regla: usa snapshot *además* de asserts específicos, no en lugar de.

---

## 7. `chart-testing` (`ct`): la capa de instalación

**`chart-testing`** (binario `ct`) es la herramienta oficialmente mantenida por la comunidad Kubernetes para validar charts. Es la que corre el repo `kubernetes/charts-testing-action` que usa toda la comunidad.

Comandos clave:

- `ct lint` — corre `helm lint` + validaciones adicionales (SemVer en `version:`, bump obligatorio al modificar un chart, Changelog opcional).
- `ct install` — para cada chart detectado como cambiado respecto a una base ref: `helm install`, espera a que todo esté `Ready`, corre `helm test`, hace `helm uninstall`.
- `ct lint-and-install` — las dos cosas.

### 7.1 Detección de charts cambiados

`ct` compara `HEAD` contra `--target-branch` (p. ej. `main`) y detecta qué charts tienen archivos modificados. Solo testea esos. Esto es la diferencia operativa clave: en un monorepo con 30 charts, un PR que toca `charts/myapp/` solo gatilla el ciclo install de `myapp`, no de los otros 29.

### 7.2 `ct.yaml` de configuración

```yaml
# ct.yaml en el root del repo
chart-dirs:
  - charts
target-branch: main
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
helm-extra-args: --timeout 600s
```

### 7.3 Cluster: `kind`

`ct install` necesita un cluster. En CI se usa **`kind`** (Kubernetes IN Docker) porque:
- Arranca en ~30s.
- Es efímero: cada job levanta uno fresco.
- Soporta **cualquier versión de Kubernetes** mediante *node images* etiquetadas (`kindest/node:v1.31.0`, `kindest/node:v1.30.0`, …).

Esta última propiedad es lo que habilita la **matriz de versiones** (§8).

---

## 8. Matriz de versiones de Kubernetes

Este es el ejercicio **de criterio arquitectónico** del módulo: ¿qué versiones de Kubernetes debe soportar tu chart?

### 8.1 Política típica (upstream)

Kubernetes mantiene **las últimas 3 minor** (política *n, n-1, n-2*). En 2026 eso típicamente significa 3 versiones vivas rotando cada 4 meses. Un chart "serio" se prueba contra las 3.

### 8.2 Trade-offs reales

| Factor | Más versiones | Menos versiones |
|---|---|---|
| Confianza para consumidores | ↑ | ↓ |
| Tiempo de CI por PR | ↑ (lineal) | ↓ |
| Mantenimiento (romper por API deprecations) | ↑ | ↓ |
| Compatibilidad empresarial (clientes con K8s viejos) | ↑ | ↓ |

### 8.3 Diseño típico de matriz

```yaml
strategy:
  matrix:
    k8s:
      - v1.31.0   # n
      - v1.30.0   # n-1
      - v1.29.0   # n-2
```

Decisiones típicas:
- Incluir siempre la **última estable**.
- Incluir la **más vieja soportada** por el consumidor principal.
- *No* probar betas en el camino crítico (opcional en nightly).
- Si el chart usa APIs que cambiaron (`autoscaling/v2`, `networking.k8s.io/v1`), **incluir la versión donde el cambio ocurrió**.

Documenta la matriz en el `README.md` del chart — es parte del contrato.

### 8.4 Costo de CI

Por versión añadida: ~2–5 min adicionales por PR (levantar `kind`, instalar, test, borrar). Multiplicado por paralelismo disponible. En un repo con mucho tráfico esto se nota en billing — la matriz es una decisión económica, no solo técnica.

---

## 9. Integración con GitHub Actions

El workflow canónico combina 3 actions mantenidas por `helm/`:

- **`helm/kind-action@v1`** — levanta un cluster `kind` con la imagen de node elegida.
- **`helm/chart-testing-action@v2`** — instala `ct` y lo expone.
- **`actions/setup-python`** o similar — `ct` requiere Python para algunas features (yamale).

Esqueleto:

```yaml
name: chart-ci
on:
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: azure/setup-helm@v4
      - name: helm lint
        run: helm lint --strict charts/*
      - name: helm template
        run: for d in charts/*/; do helm template rel "$d" >/dev/null; done

  unittest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - name: install helm-unittest
        run: helm plugin install https://github.com/helm-unittest/helm-unittest
      - name: run unittests
        run: for d in charts/*/; do helm unittest "$d"; done

  install:
    needs: [lint, unittest]
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        k8s: [v1.31.0, v1.30.0, v1.29.0]
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: azure/setup-helm@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - uses: helm/chart-testing-action@v2
      - uses: helm/kind-action@v1
        with:
          node_image: kindest/node:${{ matrix.k8s }}
      - name: ct install
        run: ct install --config ct.yaml --target-branch main
```

Observaciones:

- `fetch-depth: 0` es necesario para que `ct` pueda hacer diff contra `main`.
- `fail-fast: false` deja ver qué versiones fallan (no solo la primera).
- `lint` y `unittest` corren en paralelo y son el "gate" barato.
- `install` solo corre si pasan los dos. Es el gate caro.

---

## 10. Errores comunes y cómo diagnosticarlos

| Síntoma | Capa que debería haberlo atrapado | Causa típica |
|---|---|---|
| `helm lint` ERROR "nil pointer" | — (es el objetivo del lint) | `.Values.foo.bar` sin `default` ni `required` |
| `helm template` falla al render | lint strict, unittest con `set:` edge | Pipe de `nindent` sobre nil, missing `with` |
| `helm template` pasa, YAML no es Kubernetes válido | `ct install` | `apiVersion` deprecado, campo inválido |
| `helm install` sube pero pods crashean | `helm test` dentro de `ct install` | Image tag mal, probe mal, env mal |
| Pasa en 1.29, falla en 1.31 | **matriz de `ct install`** | API removida, feature gate que cambió |
| Snapshot test falla sin cambio aparente | — (señal verdadera) | `_helpers.tpl` cambió labels standard; o se añadió un campo |

Flujo de debug típico:

1. **Reproduce local primero**: `helm template rel ./charts/x -f values-x.yaml --debug`.
2. Si falla en `ct install` solo en una versión: `kind create cluster --image kindest/node:vX.Y.Z` y repite install manual.
3. Para unittest fallando, corre `helm unittest -f tests/<suite>_test.yaml ./charts/x` con filtro.

---

## 11. Buenas prácticas y antipatterns

**Buenas prácticas**:

- **`required`** sobre inputs sin default razonable (en vez de dejar que el YAML salga con `null`).
- **`values.schema.json`** publicado — es validación barata que ocurre antes de rendering, falla rápido.
- Un `tests/` por template, no un monolito.
- **Snapshots solo para templates estables**, no para los dinámicos.
- **`ct install` con matriz** siempre, incluso para charts pequeños — tarde o temprano llega un cambio de API.
- `fetch-depth: 0` en checkout del job `ct` — sin esto, `ct` no detecta charts cambiados.
- Pin la versión del action (`@v2`, no `@main`) para builds reproducibles.

**Antipatterns**:

- Snapshot *único* que cubre "todo" el chart — se actualiza en cada PR, nadie lo lee, no detecta nada.
- Unittest que solo comprueba `isKind` sin verificar valores — pasa con cualquier output.
- Matriz con una sola versión — ahora o nunca atraparás un bug de versión.
- `ct install` sobre un chart que **requiere credenciales externas** (p. ej. `ingress` con un `secretRef` cloud) — fallará y confundirá el pipeline. Usa values de prueba.
- Correr `ct install` en cada push a cualquier branch — paga el coste sin necesitarlo. Restríngelo a PRs a `main`.

---

## 12. Preguntas de evaluación

1. Enumera las 4 capas de la pirámide y da **un ejemplo concreto de bug** que atrape cada una pero *no* la anterior.
2. Un PR solo modifica `_helpers.tpl` del chart. ¿Qué capas de testing son más valiosas en ese PR y por qué?
3. Diseña una matriz de versiones de Kubernetes para un chart que: (a) va a Artifact Hub público; (b) solo se usa dentro de una empresa con un cluster EKS 1.30. Justifica cada caso.
4. Un `helm unittest` test falla con `expected .spec.replicas to be 3, got null`. Lista 3 causas posibles en el template.
5. ¿Por qué `fetch-depth: 0` es obligatorio para `ct install` en GitHub Actions?
6. Un snapshot test se actualiza en **todos** los PRs. ¿Qué está mal y qué refactor propones?
7. Un chart pasa `ct install` en `v1.29.0` y falla en `v1.31.0` con `the server could not find the requested resource (post policy/v1beta1)`. ¿Qué pasó y cómo lo arreglas?
8. Diferencia entre `helm lint --strict` y sin `--strict`. ¿Cuál usarías en CI y por qué?
9. ¿Puede un `helm-unittest` atrapar un error de admission webhook? Si no, ¿quién debe atraparlo?
10. ¿Por qué `ct install` solo testea charts *cambiados*? ¿Qué cambia si forzaras `--all`?
