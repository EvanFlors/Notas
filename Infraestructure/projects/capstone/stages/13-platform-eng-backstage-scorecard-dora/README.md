# Capstone — Etapa 13: Platform Engineering (Backstage + Scorecard + DORA)

> Fase 5 del programa · Dominio tocado: D11 (Platform Engineering).
> Stack fijado: **Backstage (Software Catalog + Scaffolder) + Scorecards + DORA metrics**.
> Esta etapa es **local-first**: validamos manifiestos estructuralmente y corremos el motor de scorecard y el `compute_dora.py` en Python puro, sin desplegar Backstage.

---

## 1. Resumen de la etapa

**Objetivo.** Cerrar el loop de "plataforma como producto" sobre el capstone: la app FastAPI se **registra** como `Component` en el catálogo de Backstage, se puede **crear un servicio nuevo** vía Software Template, se **mide su madurez** con un Scorecard (`bronze` / `silver` / `gold`), y se **computan los 4 DORA** sobre eventos sintéticos de CI/CD.

**Delta vs. etapa 12 (DevSecOps).**

- Antes: ESO + Kyverno + Falco corren en el cluster y protegen el *runtime*.
- Ahora: añadimos la **capa de developer experience** encima. Firmas, SBOM, SLOs y runbooks de las etapas 9–12 pasan a ser **inputs del scorecard**, no artefactos sueltos.
- Las ocho etapas anteriores dejan de ser "cosas sueltas en el README" y se consolidan en un `catalog-info.yaml` que es **la vista oficial del servicio**.

**Fuera de scope (lo verás después).**

- Despliegue real de Backstage (requiere Node + base de datos + plugin install) → se queda como walkthrough en `resources/links.md`.
- Plugin propio de Backstage → cubierto en el módulo `08-plugins-ecosystem-and-custom-plugin` del curso, no aquí.
- Crossplane / Humanitec para self-service de infra → módulo `09-self-service-infra-crossplane-and-templates`.
- TechDocs renderizado → módulo `07-techdocs-docs-as-code`.
- Chaos engineering y DR → Etapa 14.

---

## 2. Arquitectura al cierre de esta etapa

```
+-------------------------------------------------------------+
|                       Developer portal                      |
|                        (Backstage UI)                       |
|                                                             |
|  +-----------------+   +-----------------+   +-----------+  |
|  |  Software       |   |  Software       |   | Scorecard |  |
|  |  Catalog        |   |  Templates      |   | plugin    |  |
|  |                 |   |  (scaffolder)   |   |           |  |
|  | Component       |   |  "fastapi       |   | reads     |  |
|  |  capstone-app   |   |   microservice" |   | annota-   |  |
|  | API             |   |                 |   | tions +   |  |
|  |  capstone-api   |   | parameters:     |   | computes  |  |
|  | Resource        |   |  - name         |   | tier      |  |
|  |  capstone-db    |   |  - owner        |   |           |  |
|  | System          |   |  - tier         |   |           |  |
|  |  capstone       |   |                 |   |           |  |
|  +--------+--------+   +--------+--------+   +-----+-----+  |
|           |                     |                   |       |
+-----------|---------------------|-------------------|-------+
            |                     |                   |
            v                     v                   v
    catalog-info.yaml      template.yaml      scorecard/
    (en el repo)           + skeleton/         fastapi-app.yaml
                                                evaluate.py
                                                     ^
                                                     | annotations
                                                     | de catalog-info
                                                     |
            +----------------+                       |
            |  CI/CD events  | ---> compute_dora.py -+--> DORA report
            |  events.json   |                            (DF, LT, CFR, FDRT)
            +----------------+
```

**Entradas.** `catalog-info.yaml`, `scorecard/fastapi-app.yaml`, `dora/events.json`, parámetros del template.
**Salidas.** Reporte scorecard por servicio (JSON + markdown), reporte DORA por servicio y bucket (`ELITE` / `HIGH` / `MEDIUM` / `LOW`), scaffolding de un nuevo microservicio (código + `catalog-info.yaml`).
**Resource list (local).** 0 recursos cloud. Python 3.10+ para los dos scripts; manifests YAML.

---

## 3. Prerrequisitos verificados

De etapas anteriores del capstone:

- [ ] Etapas 1–4: app FastAPI con tests, repo versionado, CI con escaneos y Dockerfile.
- [ ] Etapas 5–6: pipeline con SBOM + firma (`cosign`) + Terraform mínimo.
- [ ] Etapa 7–8: desplegada en K8s (ya hay un `Deployment` y un `Service`).
- [ ] Etapa 9: Helm + Argo CD (hay un `Application` o `ApplicationSet`).
- [ ] Etapa 10: Argo Rollouts (hay evidencia de deploys progresivos).
- [ ] Etapa 11: SLOs definidos y Prometheus/Grafana levantados.
- [ ] Etapa 12: ESO + Kyverno + Falco corriendo. Imagen firmada, PSA en modo `restricted`.

Del entorno local:

- [ ] `python3 --version` ≥ 3.10.
- [ ] `python3 -c 'import yaml'` sin error (`pip install --user pyyaml`).
- [ ] `bash` y utilidades POSIX (`find`, `grep`).

Si Backstage está realmente levantado en tu entorno de aprendizaje, puedes importar `backstage/catalog-info.yaml` desde su UI (Register existing component). No es obligatorio para cerrar esta etapa.

---

## 4. Implementación guiada

Los artefactos de referencia viven bajo `backstage/`. Los *drills* repetibles viven en `activities/`.

### 4.1 Registrar el servicio en el catálogo

Edita `backstage/catalog-info.yaml`. Es un archivo multi-doc con cuatro kinds:

- `Component` (`capstone-app`): el servicio en sí. `spec.type: service`, `spec.lifecycle: production`, `spec.owner: team-capstone`, `spec.system: capstone`, y `spec.providesApis: [capstone-api]`.
- `API` (`capstone-api`): la API OpenAPI que expone. En producción esto apunta al `openapi.yaml` del servicio.
- `Resource` (`capstone-db`): la Postgres que lo respalda. `spec.type: database`.
- `System` (`capstone`): agrupa los tres anteriores. `spec.owner: team-capstone`.

**Por qué cuatro kinds y no uno.** El catálogo es un **grafo**. Si todo cae en `Component`, pierdes la relación "este servicio consume esta BD" y "este servicio expone esta API", que son las que después alimentan vistas de impacto y análisis de dependencias.

Las anotaciones (`annotations:`) son el **contrato con los otros plugins**: Scorecard lee `annotations.image_signed`, `annotations.slo_url`, etc. Un servicio sin anotaciones es invisible al scorecard.

### 4.2 Scaffolder: template para crear nuevos microservicios

Edita `backstage/template-microservice/template.yaml`. Es un `Template` de Backstage con:

- `parameters`: tres bloques (identidad, owner y tier, repo destino). Tipos `string` con `enum` cerrado en `tier` para evitar texto libre.
- `steps`:
  1. `fetch:template` que lee de `./skeleton` y sustituye `${{ values.name }}` y amigos.
  2. `publish:github` (comentado — en local no publicamos a GitHub real).
  3. `catalog:register` que registra el `catalog-info.yaml` recién generado.

El `skeleton/` incluye un `main.py` mínimo, un `pyproject.toml`, un `tests/` placeholder y el `catalog-info.yaml` ya anotado con `owner`, `tier` y los stubs vacíos de `slo_url`, `runbook_url`, `image_signed`.

**Por qué `catalog-info.yaml` nace en el skeleton (y no se añade después).** Para que **ningún servicio nuevo nazca huérfano**. Si el template lo olvida, cada servicio tiene que recordarlo "a mano" y la mitad se olvida. Esto es *paved road*: lo correcto es también lo más fácil.

### 4.3 Scorecard con niveles de madurez

Edita `backstage/scorecard/fastapi-app.yaml`. Modelo:

- `levels: [bronze, silver, gold]` — niveles ordenados, no pesos opacos.
- `checks:` ocho reglas, repartidas 1 / 3 / 4:
  - **bronze (1)**: `has-owner`.
  - **silver (3)**: `has-slo`, `has-runbook`, `has-oncall`.
  - **gold (4)**: `image-signed`, `no-critical-cves`, `deployed-recently` (< 90 días), `psa-restricted`.

Cada check tiene `id`, `weight` (= nivel), `field` (ruta dot en `metadata.annotations.*` o `spec.*`), `operator` (`is_set` / `equals` / `less_than`), y `description`. Una regla **sin descripción no entra**: cada check debe poder redirigir al equipo a una página que diga "cómo arreglar esto".

Ejecuta la evaluación:

```bash
cd projects/capstone/stages/13-platform-eng-backstage-scorecard-dora
python3 backstage/scorecard/evaluate.py \
  --scorecard backstage/scorecard/fastapi-app.yaml \
  --catalog backstage/catalog-info.yaml
```

Imprime: para cada componente del catálogo, qué checks pasa, en qué nivel queda y cuáles son los checks pendientes para subir al siguiente.

**Por qué niveles como conjuntos (no pesos sumables).** Un servicio en "gold" cumple **todos** los de gold, no "la mayoría". Esto evita el gaming de pasar checks baratos para subir el score mientras los importantes siguen rojos.

### 4.4 DORA desde eventos sintéticos

Edita `backstage/dora/events.json` y `backstage/dora/compute_dora.py`. El JSON contiene tres tipos de evento:

- `commit_merged` (sha + merged_at)
- `deploy` (id + env + commit_sha + started_at + finished_at + status)
- `incident` (caused_by_deploy_id + started_at + resolved_at)

El script calcula las cuatro métricas DORA sobre una ventana rodante (por defecto 28 días):

- **Deployment Frequency** = deploys exitosos / ventana.
- **Lead Time for Changes** = mediana de `deploy.finished_at - commit.merged_at`.
- **Change Failure Rate** = fracción de deploys que causaron un incidente.
- **Failed Deploy Recovery Time** = mediana de `incident.resolved_at - incident.started_at`.

Y clasifica el servicio en el bucket `ELITE` / `HIGH` / `MEDIUM` / `LOW` del reporte DORA reciente (umbrales explícitos en el código).

```bash
python3 backstage/dora/compute_dora.py backstage/dora/events.json
python3 backstage/dora/compute_dora.py backstage/dora/events.json --service capstone-app --json
```

**Por qué `median` y no `mean` para lead time y recovery.** Un deploy monstruo (ventana de mantenimiento de 72 h) le mete sesgo brutal al promedio. La mediana cuenta la experiencia típica.

---

## 5. Actividades del estudiante

| ID | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-13-01-register-in-backstage` | guided-lab | 40 min | Escribir `catalog-info.yaml` para la app FastAPI y validar que carga limpio (4 kinds, 1 System). |
| `cap-13-02-scaffold-new-service` | independent | 50 min | Usar `template.yaml` para generar `svc-reports/` con anotaciones correctas; probar que `evaluate.py` lo lee. |
| `cap-13-03-measure-dora` | debug | 45 min | Partir de un `events.json` roto (fechas inválidas, deploys sin commit) y repararlo hasta que `compute_dora.py` emita un bucket consistente para `capstone-app`. |

El criterio "al menos una `independent` o `debug`" se cumple con 2 y 3.

---

## 6. Entregables

1. `backstage/catalog-info.yaml` con 4 documents (Component + API + Resource + System).
2. `backstage/template-microservice/template.yaml` + `skeleton/` renderizable.
3. `backstage/scorecard/fastapi-app.yaml` + `evaluate.py` que imprime adopción por nivel.
4. `backstage/dora/compute_dora.py` + `events.json` sintético con ≥ 15 eventos.
5. Las 3 actividades con sus `validate.sh` en verde.

---

## 7. Pruebas y criterios de aceptación

Chequeos automáticos (todos corren sin red):

- [ ] `python3 -c 'import yaml,sys; list(yaml.safe_load_all(open("backstage/catalog-info.yaml")))'` sin error y con 4 docs.
- [ ] `python3 -c 'import yaml; yaml.safe_load(open("backstage/template-microservice/template.yaml"))'` sin error.
- [ ] `python3 -c 'import yaml; yaml.safe_load(open("backstage/scorecard/fastapi-app.yaml"))'` sin error, `levels` = `[bronze, silver, gold]`, ≥ 5 checks.
- [ ] `python3 backstage/scorecard/evaluate.py --scorecard backstage/scorecard/fastapi-app.yaml --catalog backstage/catalog-info.yaml` sale en 0.
- [ ] `python3 backstage/dora/compute_dora.py backstage/dora/events.json --json` imprime JSON con `bucket` ∈ `{ELITE,HIGH,MEDIUM,LOW}`.
- [ ] Cada actividad: su `tests/validate.sh` sale en 0.

Criterios de calidad:

- [ ] Cero secretos reales en los manifiestos (todo `dummy_*` o anotaciones URL).
- [ ] Todas las anotaciones usadas por el scorecard existen en al menos un `Component` del catálogo.
- [ ] El scorecard tiene ≤ 8 checks (anti-sobreinflación).
- [ ] `compute_dora.py` no depende de nada fuera de la stdlib.

---

## 8. Costos y limpieza

**Costo cloud:** $0.00 — todo corre localmente. Backstage real levantado localmente ocuparía ~1 GB de RAM pero no requiere cloud.

**Limpieza:**

```bash
rm -rf /tmp/cap-13-* /tmp/svc-reports
```

Si levantaste Backstage real, apágalo con `yarn dev` → `Ctrl+C`.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Scorecard inflado a 40 checks termina ignorado. | El modelo fija 8 y la regla es "agregar uno requiere matar otro". |
| El equipo trata DORA como ranking para castigar. | El reporte imprime bucket por servicio, pero la actividad enfatiza que la publicación debe ser **por sistema**, no "ranking entre devs". |
| El catálogo se desincroniza del código. | `catalog-info.yaml` vive **en el repo del servicio** (no en el repo de Backstage), y el template garantiza que nace con él. |

**Hints progresivos.**

1. ¿Falla `evaluate.py` con `KeyError`? Un `annotations.*` del scorecard no existe en el componente. Añádelo o quítalo del scorecard.
2. ¿`compute_dora.py` imprime `bucket: LOW` con pocos deploys? La ventana por defecto es 28 días; si tus eventos son de un día, usa `--window-days 1`.
3. ¿`validate.sh` falla con "expected 4 docs"? Faltó un `---` entre `Component` y `API` en el YAML multi-doc.

---

## 10. Puente con la siguiente etapa

**Qué habilita esta etapa.** La etapa 14 (load testing + chaos ligero + DR plan) necesita saber **qué servicio tocar** y **con qué baseline comparar**. El catálogo responde el "qué" (System `capstone`), el scorecard responde el "en qué nivel está" (si está en `bronze`, chaos es prematuro), y DORA responde el "cuánto empeoró" después del experimento.

**Qué dejamos corriendo.** Nada permanente. Los manifiestos quedan versionados; los scripts se corren bajo demanda.

**Cliffhanger.** Si ya mides DORA en condiciones normales, ¿qué pasa con los números cuando le tiras latencia inyectada a Postgres o matas una AZ entera? ¿Tu MTTR es un número de brochure o aguanta un load test real? Eso lo mide la etapa 14.
