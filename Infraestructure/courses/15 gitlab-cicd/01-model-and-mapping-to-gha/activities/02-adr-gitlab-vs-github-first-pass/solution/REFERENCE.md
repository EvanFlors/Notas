# REFERENCE — gl-01-02-adr-gitlab-vs-github-first-pass

> Una **referencia** razonada. **No es la única respuesta correcta** — otra persona podría defender razonadamente lo contrario. Compárate por *calidad de argumentación*, no por el veredicto.

---

# ADR 001 — Plataforma CI/CD: GitLab vs GitHub Actions (primera pasada)

## Estado

Propuesto (gl-01, primera pasada). A revisar al cerrar `gl-10` con una **segunda pasada** basada en experiencia práctica con GitLab.

## Contexto

`acme` es una startup de 20 personas (10 ing., 3 data, 2 security, 5 negocio) con **15 repos activos en GitHub.com** y GHA como CI/CD desde hace 2 años. Novedades:

- **Compliance**: SOC 2 Type I en 6 meses; PCI-light en el workload `checkout` en 9 meses.
- **Residencia de datos**: todo en Europa (`eu-west-1` / `eu-central-1`).
- **Operativa**: 3 áreas (`platform`, `checkout`, `analytics`); el equipo de security es de 2 personas y necesita gobernanza central.
- **Incidente reciente**: un token filtrado en logs. Falta `secret scanning` / `secret detection` sistemático y masking consistente.
- **Presupuesto**: razonable (seat-based), pero sin margen para pagar dos stacks en paralelo durante años.
- **Capacidad de plataforma**: 1 persona a tiempo parcial para platform engineering en los próximos 6 meses.

El CTO pregunta: *¿nos quedamos, migramos o convivimos?* La respuesta debe considerar el coste de **mover 15 repos** vs el valor marginal real de cambiar de plataforma a estas escalas.

## Decisión

Elegimos **quedarnos en GitHub Actions por 12 meses** y compramos **GitHub Team + GHAS + GHE Cloud** para cubrir el gap de compliance y secret scanning, con un **spike dedicado a GitLab Ultimate SaaS en 6 meses** si la organización crece a 40+ personas o aparecen requisitos de **Self-Managed**/aire-gapeado.

Horizonte: 12 meses, revisar al cerrar `gl-10` del curso o al cumplirse cualquiera de los *triggers de reevaluación* (ver §Consecuencias).

### Tabla comparativa (ejes decisivos)

| Eje | GitHub Actions (Team + GHAS + GHE Cloud) | GitLab Ultimate (SaaS) | Ganador para `acme` hoy |
|-----|-----------------------------------------|------------------------|-------------------------|
| **Compliance SOC 2 / PCI** | GHAS cubre code scanning + secret scanning; GHE Cloud suma SAML/SCIM y audit log | Ultimate agrupa SAST/DAST/SCA/Container/IaC/Secret/License + Security Dashboard + Compliance Framework | GitLab marginalmente mejor; GHA suficiente para SOC 2 Type I |
| **Residencia Europa (`eu-*`)** | Jobs corren donde el runner viva (self-hosted en eu si hace falta); datos de org pueden pedirse en regiones concretas con planes elevados | SaaS GitLab permite residencia en planes equivalentes; CE/Dedicated también | Empate |
| **Self-Managed gratuito** | No existe (GHES es de pago) | **CE** gratis | GitLab (no aplica hoy a `acme`, pero sí como opción futura) |
| **Subgroups anidables / gobernanza jerárquica** | No existe; se simula con naming + Teams | Nativo; `acme/checkout/*`, `acme/platform/*` | GitLab |
| **CI/CD Catalog interno** | Reusable workflows (Free) | Components + Catalog (Free consumo; publicación con límites); patrón 2023+ | GitLab marginalmente |
| **Marketplace / ecosistema de acciones públicas** | Marketplace enorme | Catalog creciente, menor masa crítica | **GHA** |
| **SSO / SCIM** | GHE Cloud (Enterprise) | Premium / Ultimate | Empate (ambos cuestan upgrade) |
| **Compliance Pipeline / Required Workflow** | Required workflows (Enterprise) | Compliance Framework (Ultimate) | Ligera ventaja GitLab (más granular) |
| **Costo de migración (desde GHA actual)** | 0 | Alto (15 repos + CI + secrets + envs + OIDC + branch protection) | **GHA** |
| **Costo de plataforma humana** | Low: ya hay práctica interna | Spike + aprendizaje de todo el equipo | **GHA** |
| **Horizonte 24 meses si crecemos a 60 personas** | Puede quedarse corto en gobernanza | Escala mejor con Subgroups y Compliance Framework | GitLab |

La decisión reconoce que **GitLab es técnicamente superior en algunos ejes** (jerarquía, suite de seguridad integrada), pero el **coste de migración ahora** (15 repos + OIDC + branch protection + envs + conocimiento del equipo) **no se amortiza en 12 meses** salvo que aparezcan triggers específicos.

## Consecuencias

### Positivas

- **Momentum conservado**: el equipo no para a aprender una plataforma nueva mientras persigue SOC 2.
- **Decisión rápida y reversible**: comprar GHAS resuelve el gap urgente (secret scanning tras el incidente) en semanas.
- **Baja carga de platform engineering**: la persona a tiempo parcial se enfoca en SOC 2 y en hardening, no en migrar runners.
- **Opción abierta**: no se cierra la puerta a GitLab; de hecho se calendariza una revisión formal.

### Negativas

- **Perdemos ventajas de Subgroups**: la gobernanza por área se seguirá simulando con naming y Teams.
- **Pagamos tres SKUs (Team + GHAS + GHE Cloud)**: TCO puede acercarse al de GitLab Ultimate; verificar al mes 6.
- **Catalog interno sigue siendo "reusable workflows"**, con menos ergonomía que CI/CD Components.
- **Si `acme` compra en 18 meses una empresa que opera en GitLab**, tendremos convivencia que no planeamos.

### Triggers de reevaluación (reabrir ADR si ocurre cualquiera)

1. Organización pasa de **40+ personas** o **40+ repos activos**.
2. Aparece requisito de **Self-Managed** / aire-gapeado (gov, defensa, salud muy regulada).
3. GitHub cambia pricing de GHAS o reorganiza su suite de seguridad de forma desfavorable.
4. Se adquiere o se adquiere a `acme` por una empresa cuyo stack ya está en GitLab.
5. Se identifica una **feature bloqueante** solo disponible en GitLab Ultimate.

## Alternativas descartadas

### Alt A: **Migrar todo a GitLab Ultimate SaaS ahora (12 meses)**

- **Pros**: suite de seguridad integrada; Subgroups; Compliance Framework.
- **Contras**: migración de 15 repos + OIDC + branch protection + secrets + conocimiento del equipo con **una sola persona** de platform a tiempo parcial. SOC 2 Type I en 6 meses se vuelve de alto riesgo.
- **Por qué no**: el costo de oportunidad (SOC 2 en riesgo) excede el beneficio marginal técnico, y los *triggers* definidos permiten reabrir sin coste.

### Alt B: **Convivir GHA + GitLab Ultimate durante 12 meses**

- **Pros**: aprendizaje gradual; evaluación empírica.
- **Contras**: dos stacks a mantener; doble coste (SKUs + mental overhead); auditores de SOC 2 preguntan por *cuál* es la fuente de verdad; convivencia **tiende a hacerse permanente por inercia**.
- **Por qué no**: `acme` no tiene capacidad de plataforma para operar dos stacks CI/CD seriamente a la vez.

### Alt C: **Quedarse en GitHub Actions sin comprar GHAS, mitigando con herramientas open source**

- **Pros**: costo mínimo.
- **Contras**: tras el incidente del token, auditar que "no vuelva a pasar" sin secret scanning gestionado es defendible pero frágil frente a auditores externos.
- **Por qué no**: coste de la mitigación casera (operación + reporte) supera el precio de GHAS en 12 meses, y la posición ante auditoría es más débil.

---

> **Nota del instructor**: una respuesta igualmente válida es **"migramos a GitLab Ultimate ahora"**, siempre que el ADR *reconozca* el riesgo del SOC 2 y proponga una mitigación concreta (p. ej. contratar un refuerzo, descartar features opcionales). Lo que no es válido es un ADR que elige una plataforma sin cuantificar el **coste de migración** ni los **triggers de reevaluación**.
