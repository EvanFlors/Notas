# Ejercicio arquitectónico — Escenario "FinPay"

## Contexto

FinPay es una API financiera que procesa pagos ACH entre bancos de EE. UU. El equipo migra **desde GitLab self-hosted** a **GitHub Enterprise Cloud** la próxima semana. Tienes dos semanas para dejar el nuevo repo operacional con la gobernanza correcta antes del primer deploy.

## Restricciones y hechos duros

1. **Equipo:** 6 ingenieros (3 backend, 2 platform, 1 security) + 1 compliance officer no-ingeniero (lee auditorías, no hace PRs).
2. **Release cadence:** 10–20 deploys a producción por semana, canary + full. Hay horario de freeze (viernes 18:00 – lunes 09:00 UTC).
3. **Auditoría:** SOC 2 Type II anual. El auditor exige demostrar:
   - Separación de funciones: quien escribe código no aprueba su propio despliegue a prod.
   - Trazabilidad: para cualquier artefacto en prod, poder responder "¿qué commit?, ¿quién lo revisó?, ¿qué CI corrió?".
   - Rotación de credenciales: ningún secreto de larga vida con acceso a prod.
4. **Infraestructura cloud:** AWS. El pipeline de deploy debe asumir un IAM role en la cuenta de prod. Hoy usan access keys estáticas rotadas trimestralmente (vas a eliminar esto).
5. **Dependencias:** proyecto Python + Terraform. Dependencias de Python vía `uv` lock; Terraform providers con `.terraform.lock.hcl`.
6. **Historial a traer:** el repo origen tiene **4 años** de historia y usan GitFlow con `develop`, `release/*`, `hotfix/*`. Pueden decidir si preservan la historia o hacen "clean cut".
7. **Riesgo real documentado:** hace 6 meses un contractor commiteó una clave AWS (rotada en 20 min, pero el incidente está en el audit log). Hace 1 año un paquete transitivo fue retirado por typo-squatting.

## Pregunta

Diseña y justifica, por escrito en `ANSWER.md`:

### D1 — Modelo de ramificación

Elige entre trunk-based / GitHub Flow / GitLab Flow / GitFlow. Justifica contra la cadencia de deploy (10–20/semana) y el freeze de fines de semana.

### D2 — Estrategia de merge

Elige entre squash-and-merge / rebase-and-merge / merge commit (no-ff). Justifica contra:
- Capacidad de `git bisect` para localizar regresiones.
- Legibilidad de `git log main`.
- Requisito SOC 2 de trazabilidad commit → revisor.

### D3 — Gobernanza del repo (Rulesets + CODEOWNERS + environments)

Diseña:
- Ruleset(s) sobre `main` (y cualquier otra rama protegida).
- `CODEOWNERS` para `infra/`, `security/`, resto.
- Environments y sus approvals/wait timers.
- Políticas de bypass: ¿quién puede, cuándo, cómo se audita?

### D4 — Autenticación GHA → AWS

Elimina las access keys estáticas. Diseña el trust policy OIDC: ¿qué `sub` claim exacto? ¿Un role por environment, uno global? ¿Qué pasa si alguien crea una rama llamada `main-admin`? Documenta la mitigación.

### D5 — Cadena de supply chain

Prioriza (ordena y argumenta) estos controles y descarta cualquiera que no valga la pena:
- Secret scanning + push protection.
- Dependabot (alerts / security updates / version updates).
- CodeQL (code scanning).
- Firma de commits (SSH o Sigstore gitsign).
- Attestations SLSA de build provenance verificadas por el deployer.
- Private vulnerability reporting.
- SBOM generado por dependency graph.

Para cada control adoptado: a qué amenaza del modelo (ver abajo) responde.

## Entregables

En `ANSWER.md`:

1. **Decisiones D1–D5** con justificación (300–500 palabras total).
2. **Trade-offs** por decisión en los 4 ejes: *blast radius de credencial comprometida*, *velocidad de integración*, *costo de auditoría*, *blast radius de un commit malicioso*.
3. **ADR** (formato Nygard: Contexto / Decisión / Consecuencias / Alternativas rechazadas) de **la decisión que más haya costado defender** (tú eliges cuál).
4. **Diagrama** (ASCII o Mermaid) mostrando el flujo end-to-end: branch → PR → required checks → environment approval → OIDC → deploy → attestation.
5. **Modelo de amenaza mínimo**: 3 amenazas priorizadas (p. ej. commit malicioso de insider, dependencia comprometida, secreto filtrado) y mapeo 1:1 a los controles de D3+D5.
6. **Un control que descartaste explícitamente** y por qué (costo > beneficio).

## Reglas

- **Sin secretos reales.** Usa placeholders tipo `arn:aws:iam::123456789012:role/finpay-deploy-prod`.
- **Sin recursos cloud reales**: es un diseño en papel, no se despliega.
- Si usas un control que no vimos en los módulos `gh-01..gh-13`, documenta por qué lo introduces (no se penaliza, pero debe ser defendible).
- Longitud total sugerida: 2–4 páginas Markdown + diagrama.
