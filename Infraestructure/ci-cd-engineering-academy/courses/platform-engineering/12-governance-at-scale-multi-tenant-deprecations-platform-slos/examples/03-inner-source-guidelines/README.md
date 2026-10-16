# Ejemplo 03 — Guía ejemplar de inner-source

> Lectura y análisis. Sin ejecución. Objetivo: tener una **guía de contribución inner-source** lista para pegar en `CONTRIBUTING.md` del repo de plataforma, con CODEOWNERS, SLAs, scope y escala *trusted committer*.

## 1. Por qué inner-source

Repasado en `theory/lesson.md` §7. En una línea:

> Inner-source es la **única** forma honesta de que una plataforma crezca más rápido que su equipo.

Lo que sigue es un **template completo** para el `CONTRIBUTING.md` del repo `platform-core`.

## 2. Scope: qué aceptamos y qué no

### 2.1 Sí aceptamos

- **Nuevos templates** del scaffolder para lenguajes o frameworks que aún no cubrimos.
- **Nuevas Compositions** de XRDs ya aprobadas (p. ej. una variante regional de `postgres-db`).
- **Mejoras no breaking** a templates o Compositions existentes.
- **Nuevos checks** para scorecards (siguiendo el schema público).
- **Bugfixes** en cualquier parte del repo.
- **Mejoras de docs** en TechDocs.
- **Nuevos tests** que suban la coverage de piezas existentes.

### 2.2 No aceptamos (sin ADR previa)

- Nuevos **XRDs** (son contratos — requieren diseño + ADR del platform team).
- **Breaking changes** en piezas existentes (van por el ciclo de deprecation, no por contribución externa).
- **Nuevos plugins** completos de Backstage (requieren revisión arquitectónica).
- Cambios en el **modelo del catalog** (afecta a todos los consumidores).
- Cambios en el **SLO** o la **política de deprecations** (son documentos de gobernanza).

### 2.3 Si tu idea está en la segunda lista

Antes de abrir PR, abre un **issue de propuesta** o preséntalo en **office hour**. El platform team evalúa, propone una ADR y, si procede, la implementación la lidera el equipo contribuyente **con mentoría** del platform team.

## 3. CODEOWNERS: quién revisa qué

El fichero `.github/CODEOWNERS` del repo:

```
# Owners por default: platform team.
* @acme/platform-core-team

# Templates por lenguaje
/templates/python/        @acme/platform-core-team @alice @bob
/templates/golang/        @acme/platform-core-team @carol
/templates/node/          @acme/platform-core-team @dave

# XRDs y Compositions
/crossplane/xrds/         @acme/platform-core-team
/crossplane/compositions/ @acme/platform-core-team @erin

# Plugins propios
/plugins/scorecards/      @acme/platform-core-team @frank
/plugins/catalog-ext/     @acme/platform-core-team

# Docs
/docs/                    @acme/platform-core-team @docs-team

# Gobernanza (siempre platform team)
/governance/              @acme/platform-core-team
/CHANGELOG.md             @acme/platform-core-team
/SLO.md                   @acme/platform-core-team
```

Reglas:

- **Al menos un owner** debe aprobar el PR.
- Para áreas con *trusted committers* (p. ej. `@alice` en `/templates/python/`), **el trusted committer puede aprobar y mergear** sin esperar al platform team.
- Para `/governance/` y `CHANGELOG.md`: **solo platform team** aprueba.

## 4. Checklist del PR

Toda PR debe incluir:

- [ ] **Descripción** del cambio: contexto, qué cambia, por qué.
- [ ] **Issue vinculado** (si existe).
- [ ] **Tests** nuevos o actualizados (coverage no debería bajar).
- [ ] **Docs** actualizadas si procede (README, TechDocs, migration-guide si aplica).
- [ ] **CHANGELOG.md** actualizado bajo `[Unreleased]`.
- [ ] **CI** en verde (lint + tests + validadores de contrato).
- [ ] **Breaking?** Si sí, label `breaking` + referencia a la ADR correspondiente.
- [ ] **Deprecation?** Si sí, fecha de hard-remove + plan de migración en la descripción.

PRs **sin descripción** o **sin tests** son devueltas sin revisión en profundidad.

## 5. SLA de review (compromiso del platform team)

- **Primer feedback**: < **3 días hábiles** desde que la PR tiene *reviewers* asignados.
- **Decisión final** (aprobar / rechazar con razones / solicitar cambios): < **7 días hábiles**.
- Si no cumplimos el SLA: **pingea** `#platform-help` + comenta en la PR. Ping no es ofensa; es la señal operativa.

El SLA aplica a **PRs completas** (checklist marcada, CI verde, descripción clara). PRs incompletas quedan a la espera y no cuentan en el reloj.

## 6. La escala *trusted committer*

Un modelo de niveles con criterios **objetivos**:

### 6.1 Contributor (nivel 0 — todos arrancan aquí)

- Puede abrir PRs.
- No puede aprobar ni mergear.
- Requiere review de un owner.

### 6.2 Trusted committer (nivel 1 — por área)

Promoción tras:

- **≥ 5 PRs merged** en el área en los últimos 6 meses.
- **≥ 2 reviews** útiles en PRs de otros en el área (comentarios sustantivos, no "LGTM" vacíos).
- Participación en **≥ 1 office hour** del platform team.
- Nominación por un owner existente del área.

Capacidades:

- Puede aprobar y mergear PRs **dentro de su área** siguiendo el checklist.
- Aparece en CODEOWNERS para esa área.
- Se le pingea para reviews del área.

### 6.3 Maintainer (nivel 2 — por área)

Promoción tras:

- **≥ 6 meses** activo como trusted committer en el área.
- **Historial** de decisiones de scope correctas (rechazar PRs que no deberían entrar, aceptar las que sí).
- **Documentación** de patrones del área (p. ej. "cómo escribir un template Python idiomático").
- Nominación por el platform team (mayoría simple).

Capacidades:

- Define **scope** del área junto con el platform team.
- Puede proponer **ADRs** del área.
- Puede firmar **releases menores** del área.
- Representa al área en reuniones de roadmap.

### 6.4 Reversibilidad

Los niveles son **revisables cada semestre**. Si una persona deja de contribuir activamente (0 PRs y 0 reviews en 6 meses), vuelve al nivel 0. **No es castigo**; es higiene operativa.

## 7. Retención de ownership por el platform team

Inner-source **no** diluye la responsabilidad final del platform team. Retenemos:

- **Visión** del producto plataforma (roadmap trimestral, prioridades).
- **Veto** sobre contribuciones que:
  - Violen el **SLO** publicado.
  - Introduzcan **lock-in** a un vendor sin justificación.
  - Rompan el **contrato** público (sin ir por ciclo de deprecation).
  - Introduzcan **seguridad** cuestionable (secrets, RBAC laxo, deps vulnerables).
- **Oncall** y respuesta a incidentes de todos los componentes.
- **Decisiones de arquitectura** mayor (plataforma de observabilidad, modelo de catalog, modelo de permisos).

El modelo es "**contribuyen, curamos, respondemos**", no "nos lavamos las manos".

## 8. Métricas de salud inner-source

Trimestralmente revisamos:

- **PRs externas al platform team** (número total, fracción del total).
- **Trusted committers activos** por área (número + distribución).
- **Time-to-first-review** por PR externa (debe quedar dentro del SLA).
- **PR acceptance rate** (fracción de PRs externas que terminan mergeadas).
- **Reversión rate** (PRs mergeadas que hubo que revertir — señal de review laxo).

Umbrales mínimos sanos (orientativos):

| Métrica | Umbral verde |
|---------|--------------|
| % PRs externas | ≥ 25 % del total |
| Trusted committers activos | ≥ 2 por área con contribuciones |
| Time-to-first-review p90 | ≤ SLA (3 días) |
| PR acceptance rate externas | 60–85 % (demasiado alto = no filtramos; demasiado bajo = mal onboarding) |
| Reversión rate | < 5 % |

## 9. Onboarding de contribuyentes nuevos

Para un desarrollador que **nunca** ha contribuido al repo:

1. **Lee** `README.md`, `CONTRIBUTING.md` y la ADR vigente (`/governance/ADR-xxx-governance.md`).
2. **Busca** issues con label `good-first-issue`.
3. **Pregunta** en `#platform-help` si no está claro el scope.
4. **Abre PR** siguiendo el checklist.
5. **Asiste** a la próxima office hour para presentarse (opcional pero recomendado).

Objetivo: que un contribuyente nuevo tenga su primera PR mergeada en **< 2 semanas** desde el primer contacto. Si tarda más, es señal de que el onboarding falla.

## 10. Qué llevarse

- Inner-source bien hecho tiene **scope explícito** (qué sí, qué no, qué va por ADR).
- **CODEOWNERS** reparte revisión; sin él, todo cae en el platform team.
- **SLA de review** público convierte el compromiso en operativo.
- La **escala trusted-committer** con criterios **objetivos** evita amiguismo y escala la operación.
- El platform team **retiene** visión, veto, oncall y arquitectura. No es "cualquiera decide cualquier cosa".
- **Métricas trimestrales** detectan si el inner-source está realmente funcionando o es decorativo.
