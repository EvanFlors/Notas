# Actividad 02 — Plan de deprecación de un playbook heredado (ADR)

## 1. Identificación

- **ID:** `ans-10-02-deprecation-plan`
- **Tecnología:** `ansible`
- **Módulo:** `ans-10-platform-patterns-when-ansible-when-not`
- **Dificultad:** advanced
- **Duración estimada:** 70–90 min
- **Tipo:** independent (ADR; sin dependencia con la actividad 01)

## 2. Contexto

Heredas el repo `ops/ansible` de la organización descrita en la actividad 01. Hay un playbook problemático que **debe retirarse**:

- **Nombre**: `playbooks/deploy-checkout-to-eks.yml`.
- **Qué hace**: usa el módulo `kubernetes.core.k8s` para aplicar manifiestos del servicio `checkout` al cluster EKS `prod-eu-west-1`. Lee los manifests desde `files/manifests/checkout/*.yaml`.
- **Historia**: se escribió hace 18 meses, cuando Argo CD no estaba estable. Hoy Argo CD lleva 12 meses sin incidentes y hay un `ApplicationSet` propiedad del team `checkout` que ya reconcilia el servicio desde `platform-gitops/apps/checkout/`.
- **Síntoma de drift**: en los últimos 60 días el playbook se corrió 4 veces (una por "pánico" durante un incidente que no tenía que ver, tres por costumbre). Cada ejecución produjo un diff que Argo CD revirtió, generando alerts en el canal `#platform-oncall`.
- **Owner nominal**: team `checkout` (3 ingenieros), que admite que no sabe por qué se sigue corriendo.
- **Consumers**: solo el propio team `checkout` y, muy ocasionalmente, un SRE en guardia que "lo ejecuta por si acaso".

Tu encargo: **redactar el plan de deprecación** como ADR, cumpliendo las reglas del contrato (actividad 01): fases, fechas, owners, migration path al reemplazo (Argo CD), canary de corte, rollback.

**Importante**: el entregable es un **documento**. No se despliega ni ejecuta nada.

## 3. Objetivos

Al terminar deberías poder:

- Explicar al team `checkout` en 5 minutos por qué su playbook se retira y qué deben hacer.
- Defender las fechas de las fases ante un stakeholder que pida "más tiempo".
- Describir qué pasa si el corte provoca un impacto no previsto (rollback plan).
- Dejar un documento que un SRE pueda leer en N+6 meses y entender la historia completa.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (especialmente §10 Deprecation path).
- Haber recorrido el `examples/01-ansible-boundaries-matrix/`.
- Haber completado `ans-04` y `ans-09`.
- Herramientas: `bash` y un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-10-deprecation
cd /tmp/ans-10-deprecation
```

Puedes usar otra ruta y pasársela al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-DEPRECATION-PLAN.md`

Formato ADR estándar:

```
# ADR 0YY — Deprecación de playbooks/deploy-checkout-to-eks.yml

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(Qué hace el playbook, por qué está obsoleto, qué dolor produce hoy.)

## Decisión
### 1. Criterios por los que se marca deprecado
### 2. Reemplazo recomendado y migration path
### 3. Owners y stakeholders
### 4. Fases y fechas
### 5. Canary de corte
### 6. Plan de rollback
### 7. Comunicación

## Consecuencias
(Positivas y negativas.)

## Alternativas descartadas
(Al menos 2 alternativas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. Encabezado con la palabra **`ADR`**.
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- Mención explícita al playbook **`deploy-checkout-to-eks`** (nombre o ruta).
- Mención a **Argo CD** (o Flux) como reemplazo.
- **Al menos 2 criterios** por los que se marca deprecado (dominio cambió, drift observado, uso bajo, dependencia abandonada, riesgo elevado...).
- **Al menos 4 fases** nombradas: **anuncio**, **freeze**, **canary**, **corte** (sinónimos aceptados: `cutoff`, `removal`), y adicional (`post-mortem`, `follow-up`).
- Mención a **owners** (nombre de team: `checkout`, `platform`).
- Mención a **rollback** o **plan de rollback**.
- Mención a **canal de comunicación** (Slack, email, canal explícito).
- Un **bloque de código** con un calendario / tabla / diagrama (fences).
- **Al menos 2 alternativas descartadas** como sub-headings o items numerados.

### 5.3 Entregable

Un archivo:

```
/tmp/ans-10-deprecation/ADR-DEPRECATION-PLAN.md
```

con las 6 secciones y el contenido mínimo.

## 6. Resultado esperado

- `ADR-DEPRECATION-PLAN.md` existe y es coherente.
- Validador en verde (`0 issue(s)`).
- Un ingeniero externo puede leerlo y ejecutar las fases sin ambigüedad.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: fechas realistas, rollback definido, comunicación concreta.
- **Reproducibilidad**: el plan sirve de plantilla para futuras deprecaciones (adaptable a otro playbook).

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-10-deprecation
```

El validador comprueba **estructura**, no semántica. Compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Qué pasa si el día del corte el team `checkout` tiene un incidente grave y nadie puede migrar su `ApplicationSet`?
2. ¿Cómo mides objetivamente que el reemplazo (Argo CD) ya es suficientemente confiable para permitir el corte?
3. Si otro team descubre el día del corte que **también** usaba el playbook (sin estar documentado), ¿qué haces?
4. ¿Dónde archivas el playbook: lo borras del repo, lo mueves a `archived/`, mantienes rama `legacy`?
5. ¿Qué métrica usarías para evitar que esto vuelva a pasar con otro playbook?

## 10. Extensiones

- Añade una sección **"Lecciones para la plantilla"**: qué partes de este ADR serían reutilizables para la próxima deprecación.
- Añade un **diagrama Gantt ASCII** con las fases.
- Diseña un **check-list de pre-corte** (10 items) que el DRI debe tildar antes de ejecutar el paso de removal.

## 11. Limpieza

```bash
rm -rf /tmp/ans-10-deprecation
```
