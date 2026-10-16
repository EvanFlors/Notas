# Actividad 02 — Proceso operativo del vuln management lifecycle

## 1. Identificación

- **ID:** `sec-14-02-vuln-mgmt-process-exercise`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent (sin dependencia de la actividad 01).

## 2. Contexto

El contrato de la plataforma (actividad 01) define *qué bloquea*. Esta actividad define *qué hacer con los findings* a lo largo del tiempo: el **vuln management lifecycle**. Un contrato sin proceso es papel; un proceso sin métricas es ruido.

El entregable es un documento operativo que un on-call pueda abrir a las 03:14 AM cuando el pager suena por un nuevo CVE Critical y sepa exactamente qué hacer.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Documentar las 6 etapas del lifecycle con **owner nombrado** por etapa.
- Definir SLA por tier con **números concretos** (horas/días).
- Enumerar al menos 5 métricas con **fórmula** y **SLO**.
- Describir un **escenario realista** aplicando el lifecycle a una nueva CVE (p.ej. openssl 3.0.x).
- Nombrar al menos 3 antipatrones y cómo el proceso los previene.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 5, 6, 7, 10).
- Haber recorrido `examples/02-sbom-inventory-store/` y `examples/03-vuln-mgmt-dashboard/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-14-vulnmgmt
cd /tmp/sec-14-vulnmgmt
```

### 5.2 Escribir `VULN-MGMT-PROCESS.md`

Secciones requeridas (nombres aproximados; el validador busca palabras clave):

#### Sección 1 — Lifecycle (6 etapas)

Documenta cada etapa con **nombre, entrada, salida, owner, métrica**. Las 6 etapas son:
1. **Detect** — fuentes: pipeline per PR, nightly baseline rescan, SBOM-driven alerting, pentest, bug bounty.
2. **Triage** — ¿es real? ¿afecta a ruta ejecutada?
3. **Prioritize** — aplica política de severidad (CVSS+EPSS+KEV) → tier.
4. **Remediate** — patch, upgrade, excepción con compensating control.
5. **Verify** — rescan prueba que desapareció.
6. **Report** — métricas al dashboard.

#### Sección 2 — SLA por tier

Tabla con **Critical / High / Medium / Low** y SLA numérico explícito.

#### Sección 3 — Métricas (≥ 5)

Al menos 5 métricas con **fórmula** y **SLO**. Debe incluir **MTTR**.

#### Sección 4 — Escenario end-to-end

Narrativa de un caso real: una nueva CVE sale, cómo pasa por las 6 etapas. Debe nombrar el **SBOM store** y una **query** (puede ser SQL pseudocódigo).

#### Sección 5 — Antipatrones

Al menos **3 antipatrones** nombrados: p.ej. excepciones sin TTL, métricas vanity, scanners en silos. Cada uno con *cómo el proceso lo previene*.

### 5.3 Validar la estructura

```bash
bash <ruta-repo>/courses/devsecops/14-platform-patterns-gates-dx-inventory-and-vuln-mgmt-lifecycle/activities/02-vuln-mgmt-process-exercise/tests/validate.sh /tmp/sec-14-vulnmgmt
```

### 5.4 Autoevaluar contra `solution/REFERENCE.md`.

## 6. Criterios de evaluación

- Owner nombrado por etapa (persona o rol, no "el equipo de seguridad" como caja negra).
- SLA tier es un número, no "lo antes posible".
- MTTR está entre las métricas.
- Escenario cubre las 6 etapas en orden.
- Los antipatrones son concretos y están contrarrestados.
