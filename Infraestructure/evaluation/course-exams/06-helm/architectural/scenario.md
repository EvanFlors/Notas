# Ejercicio arquitectónico — Plataforma interna de charts Helm

**Duración orientativa:** 30–40 min dentro de los 90–120 min totales.
**Dimensión:** arquitectónica (con solape conceptual).
**Modalidad:** take-home escrito u 15 min live con instructor para
preguntas de seguimiento.

## Contexto

Trabajas en el equipo de plataforma de una empresa SaaS con **~40
microservicios** mantenidos por **6 equipos de producto** sobre un único
clúster EKS multi-tenant por entorno (dev, stg, prod). Cada equipo
despliega entre 3 y 10 servicios. La organización ya decidió **GitOps con
Argo CD** como motor de release en stg y prod; en dev los equipos usan
`helm upgrade --install` desde su CI.

Hoy conviven tres estilos de empaquetado:

1. Charts "a mano" por servicio, copiados y pegados entre repos
   (deriva: cada equipo arregló distinto el mismo bug de probes).
2. Un **umbrella chart** por entorno que agrupa 10+ servicios en una sola
   release (bloqueó un deploy de pagos por una migración de catálogo).
3. Un servicio nuevo que un equipo quiere empaquetar con **Kustomize**
   porque "Helm le queda chico".

Compliance exige a 3 meses:

- Firma verificable de todo artefacto desplegado en prod.
- Pin inmutable por digest para artefactos externos.
- Air-gapped pull para el clúster de un cliente regulado.

## Tu encargo

Diseñar la **estrategia de empaquetado y distribución de charts** y
documentarla como **ADR**. Debe cubrir, mínimo:

### D1 — Modelo de chart (C2, C6, C10)

- Un **library chart** interno (`platform-lib`) con helpers compartidos
  (labels, probes, SecurityContext por default, networkPolicy base), **o**
  un **"golden" application chart** parametrizado por values, **o** una
  combinación. Defender la elección con 2 trade-offs concretos por cada
  alternativa descartada.
- Política para **umbrella charts**: ¿permitidos? ¿sólo en dev? ¿nunca en
  prod? Justificar en función del acoplamiento de lifecycle de los equipos.

### D2 — Contrato multi-entorno (C5, C12)

- Estructura de `values*.yaml` por servicio y por entorno.
- Papel de `values.schema.json` como contrato: ¿qué campos son
  obligatorios, cuáles son opt-in, cuáles son `global:` compartidos (p. ej.
  registry, dominio base), cuáles vienen por `import-values` del
  `platform-lib`?
- Cómo evitas filtrar secretos: dónde viven (external secrets operator,
  SOPS en Git, Sealed Secrets…) y qué **no** debe entrar nunca en
  `values*.yaml`.

### D3 — Distribución, firma y verificación (C8)

- Elegir entre **repo HTTP (`index.yaml`)**, **OCI (GHCR / ECR)** o ambos.
- Firma: `.prov` + GPG vs **cosign keyless + OIDC** sobre OCI. Decidir y
  explicar qué firmas se exigen en qué entorno.
- Pin: ¿pedir a Argo CD `targetRevision` por versión SemVer, por digest,
  o ambos? ¿Qué pasa si un chart interno saca `0.4.2` con un breaking de
  values? ¿Cómo lo bloqueas?
- Cumplir el requisito **air-gapped**: `helm pull` + bundle, mirror OCI
  privado, o algo más. Justificar.

### D4 — Integración con Argo CD y límites de Helm (C10)

- Argo CD **renderiza** el chart (no corre `helm install`): consecuencia
  concreta sobre **hooks** de Helm. ¿Qué hooks mantienes, cuáles migras a
  recursos nativos (`Job` + `argocd.argoproj.io/sync-wave`), cuáles mueves
  a un operador?
- Dibujar el límite: ¿qué casos de uso de la plataforma **salen** de Helm
  hacia **Kustomize** (post-rendering vía `--post-renderer`) o hacia un
  **operador** propio? El servicio que quiere migrar a Kustomize: ¿lo
  dejas, lo integras vía post-renderer, o lo convences de quedarse? Defender
  con 1 criterio objetivo.

### D5 — Gobernanza y versionado (C6, C10)

- Política SemVer de `platform-lib` y de los charts internos. Cómo manejas
  deprecations (notas, "migration guide", ventana mínima).
- Qué métricas o checks automatizados usarías para detectar que un equipo
  pin-eó `0.0.0` o copió el chart al vendor en vez de consumirlo (deriva).

## Entregables

1. **ADR** (formato Michael Nygard o MADR, 1–2 páginas) con contexto,
   decisión, consecuencias y alternativas descartadas con el **por qué**
   del descarte. Debe mencionar explícitamente D1–D5.
2. **Diagrama** (Mermaid o ASCII) de la línea Helm ↔ Kustomize ↔ operador
   y del flujo chart → firma → registry → Argo CD → clúster.
3. **Tabla de riesgos** con ≥ 5 riesgos de la decisión y mitigación
   concreta (no "monitoreo").
4. **Snippets** reales (no pseudocódigo):
   - `Chart.yaml` del `platform-lib` (`type: library`).
   - `Application` de Argo CD apuntando a OCI con `targetRevision` fijado.
   - `cosign verify` que el pipeline de admisión ejecuta.

## Criterios de evaluación

Ver `../EXAM.md` sección 5 (rúbrica arquitectónica). Peso en el total del
examen: **25%**. Resuelve antes de empezar: ¿qué decisión tomarías **tú**
si tuvieras que firmarla hoy? La rúbrica premia **defender** una decisión
con trade-offs, no enumerar opciones.
