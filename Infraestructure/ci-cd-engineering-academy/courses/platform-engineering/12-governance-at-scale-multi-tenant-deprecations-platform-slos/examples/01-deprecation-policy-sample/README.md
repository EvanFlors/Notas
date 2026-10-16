# Ejemplo 01 — Política ejemplar de deprecations (muestra para calcar)

> Lectura y análisis. Sin ejecución. Objetivo: tener a mano una **política ejemplar** de deprecations que puedas adaptar a tu organización, con un **caso trabajado** (deprecar el template `golden-path-webservice-v1` a favor de `v2`).

## 1. Alcance de la política

Esta política aplica a **todas las piezas públicas** de la plataforma:

- Templates del scaffolder de Backstage.
- XRDs de Crossplane y sus Compositions.
- APIs internas expuestas por plugins propios.
- Librerías compartidas (p. ej. `platform-sdk-python`).
- Golden paths completos.

No aplica a:

- Scripts internos del propio platform team.
- Experimentos marcados como `alpha` en el catalog (que viven bajo "úsalo bajo tu riesgo").
- Dashboards de Grafana (son UI, no contrato).

## 2. Los tres estados

Toda pieza publicada está en **uno** de estos tres estados en todo momento. El estado es **público** (visible en el catalog y en el changelog).

### 2.1 Supported

- Es la versión que recomendamos.
- Platform team **acepta features**, **acepta bugs**, **incluye en roadmap**.
- Tiene **SLO completo** publicado.
- Documentada como "versión actual" en todas las referencias.

### 2.2 Maintenance

- Versión anterior aún disponible pero **no recomendada** para nuevos usos.
- Platform team **solo acepta bugs críticos** y **security fixes**.
- **No acepta features**.
- Tiene **SLO reducido** (sin burn-rate alerts, pero sigue siendo "no cae").
- Documentada como "aún disponible — migra cuando puedas".

### 2.3 Legacy (deprecated)

- Versión en ciclo de retirada activo.
- Platform team **solo acepta security fixes**.
- **No tiene SLO**.
- Documentada con **fecha de hard-remove**.
- Emite warnings en cada uso.
- No disponible para nuevos adoptadores (soft-remove al menos).

Una pieza no puede saltar de **supported** a **legacy** directamente. Pasa primero por **maintenance** durante al menos un trimestre.

## 3. El ciclo (TTLs explícitos)

```
    t0           t0 + 30d        t0 + 90d          t0 + 180d
     │               │               │                  │
     ▼               ▼               ▼                  ▼
  ANUNCIO         WARN          SOFT-REMOVE        HARD-REMOVE
```

TTLs recomendados por tipo (son **mínimos**; se pueden alargar, nunca acortar sin acuerdo con afectados):

| Tipo de pieza          | Anuncio → warn | Warn → soft | Soft → hard | Total mínimo |
|------------------------|----------------|-------------|-------------|--------------|
| Template del scaffolder | 30 d          | 30 d        | 30 d        | **90 d**     |
| XRD de Crossplane       | 60 d          | 60 d        | 60 d        | **180 d**    |
| API interna             | 90 d          | 90 d        | 180 d       | **360 d**    |
| Golden path mayor       | 90 d          | 90 d        | 180 d       | **360 d**    |
| Librería compartida     | 60 d          | 90 d        | 180 d       | **330 d**    |

Si un uso en producción está **bloqueado** por su propia operativa de negocio (p. ej. una regulación financiera que impide migrar un servicio hasta cierto trimestre), **extensiones negociadas** son posibles — se registran en el issue de deprecation.

## 4. Qué pasa en cada fase

### 4.1 Anuncio

- Entrada en `CHANGELOG.md` del repo correspondiente.
- Post en `#platform-announcements` (Slack).
- Correo semanal con "piezas que has adoptado y están ahora deprecated".
- Marca `deprecated: true` + `deprecation_date` + `removal_date` en el YAML del template / XRD / spec de API.
- Entidad en el catalog con `metadata.annotations.platform.io/lifecycle: deprecated`.

### 4.2 Warn

- Cada uso emite warning observable:
  - Template del scaffolder: banner rojo "deprecated — remove: YYYY-MM-DD" visible en el UI.
  - XRD: anotación `deprecated.platform.io/removal-date: YYYY-MM-DD` en el Managed Resource; controller emite log `WARN`.
  - API: header de respuesta `Deprecation: true` + `Sunset: <RFC-7231 date>`.
  - Librería: `DeprecationWarning` en runtime + warning en `pip install` (vía classifier).
- Office hour mensual repasa qué está en warn.

### 4.3 Soft-remove

- Nuevos adoptadores **no pueden** elegir la pieza:
  - Template oculto del listado del scaffolder (pero ejecutable con URL directa si ya hay instancias).
  - XRD solo activa en namespaces/tenants que ya la usan (vía `AppProject` whitelist invertida).
  - API detrás de feature flag `legacy_api_<name>_enabled=true`.
- Toda ejecución nueva requiere **approval explícito** del platform team (ticket + justificación).

### 4.4 Hard-remove

- Pieza eliminada del repo.
- Entrada en `CHANGELOG.md` marcada como `Removed`.
- Si queda alguien usándola, es un **incident ticket** con escalación: la plataforma dejará de operarla; el afectado tiene N horas para migrar o aceptar el downtime.
- Postmortem interno si hubo que **extender** la hard-remove por casos no detectados en soft-remove — eso significa que el aviso falló.

## 5. Comunicación: cadencia mínima

| Momento | Canal | Audiencia |
|---------|-------|-----------|
| Anuncio inicial | Changelog + Slack `#platform-announcements` | Toda ingeniería |
| Transición entre fases | Slack `#platform-announcements` | Toda ingeniería |
| Semanal (automático) | Email a owners afectados | Equipos con usos activos de piezas deprecated |
| Mensual | Office hour | Interesados en profundizar |
| Trimestral | Changelog agregado + presentación en all-hands de ingeniería | Toda ingeniería + leadership |

El principio: **nadie debería enterarse** de que su pieza deprecated hoy desaparece. Si pasa, es un fallo nuestro, no suyo.

## 6. Caso trabajado: `golden-path-webservice-v1` → `v2`

Supongamos la realidad siguiente:

- **v1**: template del scaffolder lanzado hace 14 meses. 42 servicios lo usaron.
- **v2**: template reescrito para soportar multi-región, con *rollout canary* y el nuevo observability stack (`otel`).
- **Breaking changes** en v2:
  - `config.region` ya no acepta `single`; mínimo lista de 1.
  - `observability.format` eliminado (ahora siempre OTel).
  - El Dockerfile base cambia a `distroless`.

### 6.1 Plan de ejecución

**Semana 0 — publicación de v2 y anuncio de v1 deprecation.**

- v2 publicado como `supported`. v1 pasa a `maintenance` (no `legacy` todavía — damos 30 d para que la gente conozca v2).
- Entrada en changelog con comparativa + migration-guide.
- Post en Slack con 3 bullets: *qué cambia, cuánto tiempo tienes, cómo migrar*.
- Office hour especial 2 semanas después: demo end-to-end de migración de un servicio.

**Semana 4 — v1 pasa a `legacy` (fase ANUNCIO del ciclo).**

- `deprecated: true` en el YAML del template.
- Entrada en catalog con `lifecycle: deprecated`, `removal_date: t0+120d`.
- Dashboard de Backstage "Deprecations" muestra 42 servicios con v1.

**Semana 8 — fase WARN.**

- Banner rojo en el UI del template al abrirlo.
- Correo semanal a owners de los 42 servicios con "tu servicio está en v1; v2 disponible; remove el YYYY-MM-DD".

**Semana 14 — fase SOFT-REMOVE.**

- v1 oculta del listado del scaffolder.
- Nuevos usos requieren ticket + aprobación del platform team.
- A esta altura esperamos **< 10 servicios** aún en v1. Si son más, revisamos qué comunicación falló.

**Semana 20 — fase HARD-REMOVE.**

- v1 borrada del repo. CHANGELOG `Removed`.
- Si quedan servicios en v1, se abre incident ticket por cada uno y platform team ayuda a migrar en < 48 h.

### 6.2 Qué se mide durante el ciclo

- **Adoption rate** de v2 (nº servicios en v2 / nº total).
- **Residual v1 count** (nº servicios aún en v1) — debería bajar monotónicamente.
- **Migration velocity** (servicios migrados por semana).
- **Office hour attendance** (indicador blando — si cae mucho, estamos solos).
- **Tickets abiertos por "no puedo migrar porque..."** — cada uno es feedback valioso.

### 6.3 Qué va al postmortem

- Si en hard-remove quedan servicios no migrados: **falló la comunicación** o **falló la migration-guide**. Postmortem obligatorio.
- Si la migration-guide tuvo que actualizarse > 3 veces durante el ciclo: **falló el diseño del breaking change**. Postmortem obligatorio.

## 7. Qué llevarse

- Un ciclo de deprecation **sin TTL explícito** no es política, es intención.
- **Tres estados** (supported / maintenance / legacy) son el mínimo honesto.
- **Comunicación proactiva** (semanal + mensual + trimestral) es parte del contrato, no cortesía.
- Un **caso trabajado** vale más que una política abstracta — este ejemplo te da la plantilla.
- Si al final queda alguien usando una pieza en hard-remove, **falló nuestro proceso**, no el suyo.
