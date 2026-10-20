# Actividad 02 — Auditar trust policies vulnerables (independiente)

## 1. Identificación

- **ID:** `gha-11-02-review-vulnerable-trust-policy`
- **Tecnología:** `github-actions`
- **Módulo:** `11-oidc-and-cloud-federation`
- **Dificultad:** advanced
- **Duración estimada:** 45–60 min
- **Tipo:** independent

## 2. Contexto

Te llegan 4 trust policies IAM para revisar en un PR. Dos van a producción, dos a staging. En apariencia son correctas: declaran `sts:AssumeRoleWithWebIdentity`, apuntan al OIDC provider de GitHub, tienen `aud` correcto. Las cuatro están, de hecho, **mal escritas**: tres son explotables (una tendría un radio de daño enorme), una es "funcionalmente" segura pero rompe convenciones del equipo.

Tu trabajo:

1. Clasificar cada trust policy como **VULNERABLE** o **SAFE_BUT_WEAK**.
2. Explicar **brevemente** por qué falla.
3. Escribir en `fixes/trust-policy-<N>.json` la versión corregida.
4. Resumir el informe en `audit.md`.

Esta actividad **no te da la solución** paso a paso. Te da los 4 archivos vulnerables y un validator que verifica que los 4 fixes son correctos y que el `audit.md` cubre los puntos esperados.

## 3. Objetivos

- Reconocer patrones vulnerables en trust policies OIDC: pin solo al owner, wildcard tras el repo, `aud`-only, `Condition` inefectiva.
- Escribir el pin correcto para cada caso (branch, environment, tag).
- Comunicar en revisión por qué cada caso es inseguro.

## 4. Prerrequisitos

- `bash`, `python3` (3.8+).
- Haber leído la sección 4 de `theory/lesson.md` (especialmente §4.2 y §9.3-§9.4).

**Costos:** USD 0. Nada toca cloud.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-oidc-audit
```

Esto copia 4 trust policies a auditar en `/tmp/gha-oidc-audit/project/vulnerable/`:

- `trust-policy-1.json` — rol `github-admin-prod`, pensado para deploy a prod desde `main`.
- `trust-policy-2.json` — rol `github-release-tagger`, pensado para pipeline de release por tag.
- `trust-policy-3.json` — rol `github-ci-read`, pensado para CI de solo lectura.
- `trust-policy-4.json` — rol `github-deploy-staging`, pensado para deploy a staging desde `environment:staging`.

### 5.2 Tareas

Trabaja en `/tmp/gha-oidc-audit/project/`:

1. Lee cada `vulnerable/trust-policy-<N>.json` con calma.
2. En `audit.md`, para cada uno:
   - Clasificación: `VULNERABLE` o `SAFE_BUT_WEAK`.
   - Descripción de 1-3 líneas del problema.
   - Qué atacante o escenario lo explota.
3. En `fixes/trust-policy-<N>.json`, escribe la **versión corregida**. Mantén el mismo propósito (prod desde main, release por tag, CI read, staging por env), pero elimina el problema.

Pistas y convenciones aceptadas por el validator:

- Fixes deben pinnear a `repo:MyOrg/<Repo>:…` **sin wildcard inicial** y **sin terminar en `:*`**.
- Fix 1 (prod desde main): acepta `sub = repo:MyOrg/<Repo>:ref:refs/heads/main` **o** `repo:MyOrg/<Repo>:environment:production`. Lo segundo es preferible.
- Fix 2 (release por tag): acepta `StringLike` `repo:MyOrg/<Repo>:ref:refs/tags/v*` (wildcard controlado tras `tags/`).
- Fix 3 (CI read): `repo:MyOrg/<Repo>:ref:refs/heads/*` es aceptable (branch wildcard controlado), **sin incluir** `pull_request` ni `environment:` arbitrarios.
- Fix 4 (staging por env): `repo:MyOrg/<Repo>:environment:staging` exacto.
- Todos deben mantener `aud = sts.amazonaws.com` y `Action = sts:AssumeRoleWithWebIdentity`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/gha-oidc-audit
```

### 5.4 Pistas conceptuales (no la solución)

- Pensá qué pasa con un repo recién creado en la misma organización.
- Pensá qué pasa con un fork que abre un PR con un workflow modificado.
- `StringLike` con `*` al final del `sub` casi siempre es demasiado laxo.
- Un trust que solo verifica `aud` acepta JWTs de **cualquier** workflow de GitHub en el mundo.
- Un `sub` sin wildcard que apunta a `pull_request` tiene sentido en muy pocos casos; para prod, nunca.

## 6. Resultado esperado

- `audit.md` presente, con las 4 clasificaciones y explicación mínima.
- `fixes/trust-policy-1.json` ... `fixes/trust-policy-4.json`, todos JSON válidos.
- Cada fix es semánticamente correcto para su propósito (ver pistas 5.2).
- `tests/validate.sh` → `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] 4 fixes JSON válidos.
- [ ] 4 fixes con pin del `sub` que empieza por `repo:MyOrg/`, no wildcard en el owner/repo, no termina en `:*`.
- [ ] Fix 1 incluye `:ref:refs/heads/main` o `:environment:`.
- [ ] Fix 2 incluye `:ref:refs/tags/`.
- [ ] Fix 3 limita a `:ref:refs/heads/` (branches, no PRs).
- [ ] Fix 4 incluye `:environment:`.
- [ ] `audit.md` menciona los 4 archivos y usa las palabras `VULNERABLE`/`SAFE_BUT_WEAK`.

## 8. Validación

El validator inspecciona los 4 fixes JSON con `python3`:

1. Parsing JSON.
2. `Version`, `Effect: Allow`, `Action: sts:AssumeRoleWithWebIdentity`.
3. `Principal.Federated` termina en `/token.actions.githubusercontent.com`.
4. `aud = sts.amazonaws.com`.
5. `sub` cumple los requisitos específicos del fix N (ver tabla en §5.2).
6. `audit.md` menciona cada `trust-policy-<N>` y usa clasificaciones esperadas.

## 9. Preguntas de reflexión

1. ¿Cuál de los 4 trust policies originales permitiría el ataque de **mayor radio de daño**? Justificá.
2. ¿Por qué `StringLike` con `repo:MyOrg/MyRepo:*` sigue siendo peligroso aunque el repo esté pinneado?
3. ¿Qué pasa con `trust-policy-3` si alguien abre un PR desde un fork con un workflow que pide el token?
4. Si tu equipo quiere permitir deploy desde cualquier `release/*` **y** desde `main`, ¿cómo escribirías el `sub` sin perder seguridad?
5. ¿Qué controles **adicionales a la trust** reducen el blast radius si la trust igual falla? (Pensá en el otro lado — permission policy, environments, ...)

## 10. Extensiones

- **E1** — Añadí un 5º caso que inventes tú y pídele a un compañero que lo revise.
- **E2** — Escribí un script `audit.sh` que, dada una carpeta de JSONs de trust, imprima el `sub` pinneado y clasifique heurísticamente cada uno.
- **E3** — Replicá el ejercicio pero para GCP Workload Identity Federation: inventá 4 `attribute_condition` CEL vulnerables y sus fixes.

## 11. Limpieza

```bash
rm -rf /tmp/gha-oidc-audit
```
