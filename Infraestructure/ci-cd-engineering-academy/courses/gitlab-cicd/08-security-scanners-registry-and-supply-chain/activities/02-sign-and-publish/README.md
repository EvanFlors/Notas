# Actividad 02 — Build, firma keyless y publicación

## 1. Identificación

- **ID:** `gl-08-02-sign-and-publish`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-08-security-scanners-registry-and-supply-chain`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de plataforma te pide armar la cadena de suministro mínima para un microservicio Node: construir una imagen, firmarla con **cosign keyless** usando el **ID Token** de GitLab como credencial OIDC a Sigstore, y verificar la firma en un job posterior. No puede existir ninguna variable `COSIGN_KEY` ni archivo PEM: todo keyless. Además documentas el cleanup policy del Container Registry y las garantías de supply chain (SBOM, estado parcial de SLSA).

**Importante**: no se corre nada en `gitlab.com`. Entregables: `.gitlab-ci.yml`, `cleanup-policy.json` y `README-INTENT.md`.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un pipeline *build → sign → verify* con stages consistentes y `needs:`.
- Usar `id_tokens:` con `aud: sigstore` y firmar el **digest** (no el tag).
- Verificar con `--certificate-identity` + `--certificate-oidc-issuer` pinneados.
- Declarar una cleanup policy razonable con `name_regex_keep` para releases.
- Explicar en Markdown qué aporta SBOM/CycloneDX y el estado parcial de SLSA.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§4 Registry, §6 SBOM, §7 SLSA, §8 cosign keyless).
- Haber recorrido `../../examples/02-container-registry-push-and-cleanup/` y `../../examples/03-cosign-keyless-with-gitlab-oidc/`.
- Herramientas: `bash`, `jq`, `python3`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/gl-08-sign
cd /tmp/gl-08-sign
```

### 5.2 Escribe `.gitlab-ci.yml`

Debe contener:

- `stages:` con **al menos** `build`, `sign`, `verify`.
- Un job `build` que use **Kaniko** (`gcr.io/kaniko-project/executor`), publique a `$CI_REGISTRY_IMAGE`, y capture el digest a un archivo (`--digest-file`) subido como artifact.
- Un job `sign` con:
  - `image: gcr.io/projectsigstore/cosign` (cualquier tag `v2.*` sirve).
  - `id_tokens:` declarando `SIGSTORE_ID_TOKEN` con `aud: sigstore`.
  - `script:` que ejecute `cosign sign --yes --identity-token "$SIGSTORE_ID_TOKEN"` sobre `$IMAGE@$DIGEST` (digest, no tag).
  - `needs: ["build"]`.
- Un job `verify` con:
  - `cosign verify` que incluya `--certificate-identity` **y** `--certificate-oidc-issuer`.
  - `needs: ["sign", "build"]`.

### 5.3 Escribe `cleanup-policy.json`

JSON válido con, al menos, estas keys:

- `enabled: true`
- `cadence: "7d"` (o similar)
- `keep_n: <int>`
- `older_than: "<N>d"`
- `name_regex_delete: "..."` que matchee `pr-\d+` o `sha-*`.
- `name_regex_keep: "..."` que preserve `v\d+\.\d+\.\d+` o `main-*`.

### 5.4 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## Build (Kaniko)` — por qué rootless, por qué sin DinD.
- `## Firma keyless con cosign` — explica `id_tokens:`, `aud: sigstore`, por qué firmar el digest.
- `## Verificacion` — `--certificate-identity`, `--certificate-oidc-issuer`, qué pasa en un fork.
- `## SBOM y SLSA` — menciona **CycloneDX** y el estado parcial de SLSA provenance.
- `## Cleanup policy` — justifica `name_regex_keep` y `keep_n`.

Y debe mencionar explícitamente las palabras: `cosign`, `sigstore`, `digest`, `CycloneDX`.

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.5 Entregables

```
/tmp/gl-08-sign/
├── .gitlab-ci.yml
├── cleanup-policy.json
└── README-INTENT.md
```

## 6. Resultado esperado

- `.gitlab-ci.yml` parsea con `yaml.safe_load`.
- `cleanup-policy.json` parsea con `jq .`.
- Validador en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud**: ninguna referencia a `COSIGN_KEY` o claves de larga vida.
- **Mantenibilidad**: `IMAGE_DIGEST` leído desde el artifact del build, no re-calculado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-08-sign
```

## 9. Preguntas de reflexión

1. ¿Por qué firmar el digest y no el tag `:latest`?
2. Si un atacante forkea el repo y corre el pipeline en su propio namespace, ¿pasa `cosign verify` del repo original? ¿Qué claim lo evita?
3. ¿Qué pasa con la firma si Sigstore (Rekor) está caído temporalmente?
4. ¿Dónde quedaría la attestation si usas `cosign attest --type slsaprovenance`?
5. Si tu `cleanup-policy.json` tiene `name_regex_keep` vacío, ¿qué consecuencia tiene en 6 meses?

## 10. Extensiones

- Añade un job `attest:` con `cosign attest --predicate provenance.json --type slsaprovenance`.
- Añade un `scan` entre `build` y `sign` con `template: Jobs/Container-Scanning.gitlab-ci.yml` y pasa el reporte como artifact.
- Añade un `verify-policy` que use `cosign verify-attestation` con un policy OPA/Rego mock.

## 11. Limpieza

```bash
rm -rf /tmp/gl-08-sign
```
