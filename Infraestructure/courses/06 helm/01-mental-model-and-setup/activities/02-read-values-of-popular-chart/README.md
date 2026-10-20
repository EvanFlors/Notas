# Actividad 02 — Analizar `values.yaml` de 3 charts populares

## 1. Identificación

- **ID:** `helm-01-02-read-values-of-popular-chart`
- **Tecnología:** `helm`
- **Módulo:** `helm-01-mental-model-and-setup`
- **Dificultad:** beginner
- **Duración estimada:** 50–75 min
- **Tipo:** independent

## 2. Contexto

Afirmamos en la lección que **`values.yaml` ES la API pública del chart**. Hasta que no has leído varios `values.yaml` de charts maduros, esa afirmación es solo retórica. Esta actividad te obliga a leerlos y a documentarlos, de modo que la frase pase de ser un slogan a una experiencia concreta.

Es **independent**: no te damos la respuesta. Eliges los 3 charts (sugeridos abajo), tú lees sus `values.yaml`, tú decides qué 5 valores por chart son los más representativos.

## 3. Objetivos

Al terminar deberías poder:

- Descargar `values.yaml` de 3 charts populares con `helm show values`.
- Reconocer qué valores son **comunes** entre charts (`image.repository`, `image.tag`, `resources`, `replicaCount`) y cuáles son **específicos del dominio** del chart.
- Documentar valores con precisión: nombre completo, tipo, default, para qué sirve, cuándo lo tocarías.
- Comparar convenciones de nombres (`replicaCount` vs `replicas`, `image.tag` vs `imageTag`, …) entre charts.
- Argumentar con tus propias palabras por qué `values.yaml` es la **interfaz pública** del chart y qué implicaciones tiene para el mantenedor.

## 4. Prerrequisitos

- Haber completado la actividad `01-install-helm-and-explore/` (binario `helm` instalado y funcional).
- Haber leído `theory/lesson.md` §2 y §4.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/helm-01-values
cd /tmp/helm-01-values
```

### 5.2 Elegir **3 charts populares**

Sugerencia (puedes sustituir por otros equivalentes si justificas la elección en `ANALYSIS.md`):

- **`ingress-nginx/ingress-nginx`** — ingress controller, repo HTTP `https://kubernetes.github.io/ingress-nginx`.
- **`jetstack/cert-manager`** — automatización de certificados TLS, repo HTTP `https://charts.jetstack.io`.
- **`prometheus-community/kube-prometheus-stack`** — stack completo Prometheus + Grafana + Alertmanager, repo HTTP `https://prometheus-community.github.io/helm-charts`.

Alternativas aceptables si uno de los anteriores no te sirve: `bitnami/postgresql`, `argo/argo-cd`, `external-secrets/external-secrets`, `grafana/loki`.

Añade los repos:

```bash
helm repo add ingress-nginx          https://kubernetes.github.io/ingress-nginx
helm repo add jetstack               https://charts.jetstack.io
helm repo add prometheus-community   https://prometheus-community.github.io/helm-charts
helm repo update
```

### 5.3 Descargar `values.yaml` de cada chart

```bash
helm show values ingress-nginx/ingress-nginx                  > values-ingress-nginx.yaml
helm show values jetstack/cert-manager                        > values-cert-manager.yaml
helm show values prometheus-community/kube-prometheus-stack   > values-kube-prometheus-stack.yaml
wc -l values-*.yaml
```

Observa el tamaño: suelen tener **cientos o miles de líneas**. Es a propósito — la API es ancha porque los casos de uso son muchos.

### 5.4 Entregable: `ANALYSIS.md`

Crea `/tmp/helm-01-values/ANALYSIS.md` con esta estructura obligatoria:

#### Secciones

```markdown
# ANALYSIS — values.yaml de 3 charts populares

## Chart 1: ingress-nginx/ingress-nginx

- Chart version: X.Y.Z
- App version:   X.Y.Z

### Valores destacados

| Valor | Tipo | Default | Para qué sirve | Lo tocarías? |
|-------|------|---------|----------------|--------------|
| controller.replicaCount | int | 1 | Nº de réplicas del controller | Sí (prod: 3) |
| controller.service.type | string | LoadBalancer | Tipo de Service del controller | Depende: bare-metal → NodePort |
| ... (al menos 5 filas) | | | | |

### Observaciones

(2-3 frases sobre convenciones del chart, cosas raras, cosas notables.)

---

## Chart 2: jetstack/cert-manager

(mismo esquema, al menos 5 valores)

---

## Chart 3: prometheus-community/kube-prometheus-stack

(mismo esquema, al menos 5 valores)

---

## Comparación entre charts

(un párrafo + una tabla pequeña: qué keys son comunes, qué convenciones divergen,
qué chart tiene mejor organizado el values.yaml y por qué.)

---

## Por qué `values.yaml` ES la interfaz del chart

(5-10 frases con tus propias palabras. Debe mencionar:
 - que es el único punto por donde el consumidor configura el chart,
 - que renombrar/eliminar keys sin bumpear major es un breaking change,
 - que `values.schema.json` formaliza esa interfaz,
 - que no leer `values.yaml` antes de instalar es instalar a ciegas.)
```

### 5.5 Requisitos cuantitativos del entregable

- **3 secciones de chart** con los encabezados `## Chart 1`, `## Chart 2`, `## Chart 3`.
- **Al menos 5 valores documentados por chart** (15 en total mínimo).
- **1 sección de comparación**.
- **1 sección final argumentando por qué `values.yaml` es la interfaz** — debe tener al menos 5 frases y mencionar los conceptos listados arriba.
- Los nombres de los 3 charts deben aparecer en el documento.

### 5.6 Validar estructura

```bash
bash tests/validate.sh /tmp/helm-01-values
```

El validador comprueba:

- `ANALYSIS.md` existe.
- Tiene las 3 secciones de chart + comparación + justificación.
- Cuenta al menos 15 valores documentados (filas de tabla con 4+ pipes `|`).
- Menciona `values.schema.json`, "API"/"interfaz" asociado a `values.yaml`, y nombres de los 3 charts.
- Los archivos `values-*.yaml` existen (prueba de que descargaste los valores).

**No valida contenido semántico** — compara tus respuestas con `solution/ANALYSIS-reference.md`.

## 6. Resultado esperado

- `/tmp/helm-01-values/` contiene:
  - `ANALYSIS.md` (entregable principal).
  - `values-ingress-nginx.yaml`, `values-cert-manager.yaml`, `values-kube-prometheus-stack.yaml` (fuentes).
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] 3 charts documentados con secciones separadas.
- [ ] 5+ valores por chart (nombre, tipo, default, propósito, "lo tocarías?").
- [ ] Comparación entre los 3 charts (convenciones, estilo).
- [ ] Justificación final clara: `values.yaml` **es** la API pública del chart.
- [ ] Menciona `values.schema.json` como formalización de esa API.
- [ ] Los 3 archivos `values-*.yaml` existen en el directorio.

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm-01-values
```

Estructural. Semántica contra `solution/ANALYSIS-reference.md`.

## 9. Preguntas de reflexión

1. Entre los 3 charts, ¿cuál tiene la API más grande (más líneas de `values.yaml`)? ¿Por qué puede justificarse esa amplitud en ese dominio?
2. ¿Encontraste algún chart con `values.schema.json`? (`helm show values` no lo muestra; mira dentro del `.tgz` con `helm pull --untar`.) ¿Qué cambia tener uno?
3. ¿Qué convenciones de nombres **no** son consistentes entre los 3 charts? (ejemplo: ¿todos usan `image.repository` y `image.tag`? ¿`replicaCount` o `replicas`?)
4. Si fueras el mantenedor del chart `kube-prometheus-stack` y quisieras **renombrar** `prometheus.enabled` a `components.prometheus.enabled`, ¿cómo lo harías sin romper a todos los consumidores? (Hint: deprecation period + alias en templates.)

## 10. Extensiones (opcional)

- **E1** — Para uno de los 3 charts, bájate el `.tgz` entero con `helm pull <chart> --untar` y busca si tiene `values.schema.json`. Si lo tiene, documenta 3 reglas de validación interesantes.
- **E2** — Simula un override pequeño con `helm template <release> <chart> --set controller.replicaCount=3 --dry-run` (sin cluster) y verifica que el Deployment renderizado refleja el cambio.
- **E3** — Elige un chart que **no** sigue las convenciones comunes (`replicas` en vez de `replicaCount`, p. ej.) y escribe en 2 frases por qué eso dificulta portar un `values.yaml` entre charts.

## 11. Limpieza

```bash
rm -rf /tmp/helm-01-values
# Opcional:
# helm repo remove ingress-nginx jetstack prometheus-community
```
