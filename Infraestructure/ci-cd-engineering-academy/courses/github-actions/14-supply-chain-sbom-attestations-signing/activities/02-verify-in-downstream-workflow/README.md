# Actividad 02 — Verificación en un workflow consumidor (downstream)

## 1. Identificación

- **ID:** `gha-14-02-verify-in-downstream-workflow`
- **Tecnología:** `github-actions`
- **Módulo:** `14-supply-chain-sbom-attestations-signing`
- **Dificultad:** advanced
- **Duración estimada:** 45–60 min
- **Tipo:** **independent** — no se da la solución en el enunciado.

## 2. Contexto

En la actividad 01 fuiste el **productor**: firmaste y attestaste. Ahora eres el **consumidor downstream**. Alguien (otro repo, otra org) publicó una imagen firmada y attestada. Tú tienes que escribir el workflow que verifica esas evidencias **antes de hacer deploy** y que falla cerrado si cualquier verificación no pasa.

Lo que recibes como input (en `starter/image-info.env`):

```
IMAGE_REF=ghcr.io/sigstore/sample-trusted-image:latest
EXPECTED_REPO=sigstore/sample-trusted-image
EXPECTED_WORKFLOW_REGEX=^https://github\.com/sigstore/sample-trusted-image/\.github/workflows/release\.yml@refs/tags/v.*$
EXPECTED_OIDC_ISSUER=https://token.actions.githubusercontent.com
```

(Estos valores son *ilustrativos*; tus tests están contra un *fixture* local que el bootstrap prepara. Más abajo.)

Tu trabajo:

- Escribir `.github/workflows/consume.yml` que:
  1. Verifica la firma de la imagen con `cosign verify` usando `--certificate-identity-regexp` y `--certificate-oidc-issuer`.
  2. Verifica la attestation de build provenance con `gh attestation verify --repo <esperado>`.
  3. Si cualquiera falla, el job falla (no debe hacer deploy).
  4. Si todo pasa, el siguiente step (`deploy`) corre.
- Escribir `verify.sh` (invocado por el workflow) con el mismo contrato — así puedes probarlo localmente y el validator también lo puede ejecutar.

## 3. Objetivos

- Diseñar un workflow consumidor con `permissions:` mínimos (solo `id-token: read` si necesitas Sigstore trust bundle, `contents: read`).
- Elegir el regex de identidad correcto: estricto a `release.yml`, `refs/tags/v*`, repo exacto.
- Elegir el OIDC issuer correcto (`https://token.actions.githubusercontent.com`).
- Diseñar el flujo "fail closed": si verificación falla, deploy no corre (en el workflow, usar `needs:` + `if: success()`).

## 4. Prerrequisitos

- Haber completado `gha-14-01`.
- Docker (opcional).
- `cosign` ≥ 2.0 (opcional para runtime; si no, el validator inspecciona YAML/shell solamente).
- `gh` CLI (opcional).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/gha-14-02
```

Esto crea:

```
/tmp/gha-14-02/
├── image-info.env                 (variables esperadas; léelas)
├── .github/workflows/             (vacío — escribes consume.yml)
├── verify.sh                      (vacío — escribes el script de verificación)
└── NOTES.md
```

### 5.2 Tarea A — `verify.sh`

Escribe `/tmp/gha-14-02/verify.sh` que:

1. Lee `image-info.env` (que define las 4 variables de arriba).
2. Verifica la firma: `cosign verify "$IMAGE_REF" --certificate-identity-regexp "$EXPECTED_WORKFLOW_REGEX" --certificate-oidc-issuer "$EXPECTED_OIDC_ISSUER"`.
3. Verifica la attestation: `gh attestation verify oci://"$IMAGE_REF" --repo "$EXPECTED_REPO"`.
4. Falla con exit != 0 si **cualquiera** de las dos no pasa.
5. **Fail closed**: si `cosign` o `gh` no están disponibles, el script debe salir con exit 2 (no 0 silencioso). Si pasa, exit 0.

Haz `chmod +x verify.sh`.

### 5.3 Tarea B — `consume.yml`

Escribe `/tmp/gha-14-02/.github/workflows/consume.yml` que:

- `on: workflow_dispatch` (o `schedule`/`push`, como quieras).
- Dos jobs: `verify` y `deploy`.
- `verify`: instala cosign (`sigstore/cosign-installer@...` pin a SHA), setup `gh` ya viene en el runner, corre `./verify.sh`.
- `deploy`: `needs: verify`, `if: success()`, placeholder `run: echo "deploy would run"`.
- `permissions:` del workflow a `contents: read`, nada más (verify no necesita `id-token: write`).

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/gha-14-02
```

Comprueba:

- Existencia de `verify.sh` ejecutable con las 4 variables + regex de identidad + issuer OIDC + llamadas a `cosign verify` y `gh attestation verify`.
- `consume.yml` presente, YAML válido, con 2 jobs, `needs: verify`, cosign installer, permissions mínimos.
- Un **anti-pattern grep**: `verify.sh` NO debe hardcodear `--certificate-identity-regexp '.*'` ni similar laxo.
- Runtime (si cosign disponible): corre `verify.sh` contra un **fixture firmado localmente** por `starter/make-fixture.sh` y confirma que (a) **pasa** con las variables correctas, (b) **falla** cuando se corrompe el regex esperado.

### 5.5 Pistas (ninguna solución)

- `cosign verify` acepta tanto `--certificate-identity` (string exacto) como `--certificate-identity-regexp` (patrón). Para versionado SemVer usa regex.
- `gh attestation verify` requiere o `--repo OWNER/REPO` o `--owner OWNER`. Para un consumidor serio, usa `--repo`.
- Si trabajas offline y `gh attestation verify` falla por red, puedes separar: cosign verify local funciona con el bundle, gh verify requiere API.
- El validator ejecuta tu `verify.sh` sobre un fixture donde ambos EXPECTED_* son controlados. Si el regex está demasiado laxo, el "negative test" (variables malas) debería *fallar* y revelar el falso-positivo.

## 6. Resultado esperado

- `verify.sh` falla ante firma inválida y pasa ante firma válida.
- `consume.yml` tiene `deploy` que depende de `verify` con `if: success()`.
- `tests/validate.sh` termina con `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] `verify.sh` ejecuta `cosign verify` con **ambos** flags `--certificate-identity-regexp` y `--certificate-oidc-issuer`.
- [ ] `verify.sh` ejecuta `gh attestation verify` con `--repo`.
- [ ] `consume.yml` tiene `jobs.deploy.needs: verify`.
- [ ] `consume.yml` tiene `permissions:` restringidos (no `write-all`, no `packages: write`).
- [ ] (Runtime) El fixture firmado localmente verifica OK; corromperlo o cambiar regex expected hace fallar `verify.sh`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gha-14-02
```

## 9. Preguntas de reflexión

1. **¿Qué pasa si el consumidor usa `--certificate-identity-regexp '.*'`?** Reconstruye el ataque posible paso a paso.
2. **¿Qué debe hacer el consumidor si Rekor no responde?** Argumenta tu política (fail closed / open / warn).
3. **El productor rota el workflow a `release-v2.yml`**. Tu regex apunta al viejo. ¿Qué pasa en el próximo release? ¿Cómo lo coordinas sin ventana de confianza rota?
4. **El consumidor y el productor son orgs distintas**. ¿Qué canal de confianza inicial establece "este regex es la identidad correcta"? (No es Sigstore; es un canal fuera-de-banda.)
5. **¿Es suficiente verificar firma, sin attestation?** Da un escenario donde una imagen correctamente firmada aún así es peligrosa.

## 10. Extensiones

- **E1** — Añade verificación de **attestation de SBOM** (`--predicate-type https://cyclonedx.org/bom`) y lee el JSON para denegar deploy si contiene paquetes con licencia GPL-3.0.
- **E2** — Añade verificación de **frescura**: rechaza firmas con timestamp Rekor mayor a 30 días.
- **E3** — Convierte `consume.yml` a un **reusable workflow** parametrizado por `image_ref` y `expected_identity_regex`.

## 11. Limpieza

```bash
rm -rf /tmp/gha-14-02
```
