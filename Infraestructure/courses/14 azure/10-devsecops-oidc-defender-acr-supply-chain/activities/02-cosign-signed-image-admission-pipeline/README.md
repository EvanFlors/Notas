# Actividad 02 — Pipeline cosign keyless + admission policy en AKS

## 1. Identificacion

- **ID:** `az-10-02-cosign-signed-image-admission-pipeline`
- **Tecnologia:** `azure`
- **Modulo:** `az-10-devsecops-oidc-defender-acr-supply-chain`
- **Dificultad:** advanced
- **Duracion estimada:** 70–85 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Seguridad te pide **blindar la cadena de suministro** de imagenes de `checkout`:

1. Toda imagen que llegue a `acrcheckoutprod` debe estar **firmada** con cosign keyless usando el OIDC del runner de GHA.
2. El cluster AKS de prod debe **rechazar** cualquier pod cuya imagen no tenga una firma cosign valida con `certificate-identity` **exactamente** `.github/workflows/build-sign-push.yml@refs/heads/main` y `certificate-oidc-issuer` `https://token.actions.githubusercontent.com`.
3. La policy va en modo `Enforce` (no `Audit`) desde el dia uno. Audit solo seria aceptable durante una ventana de rollout.

Tienes que escribir:

- El **workflow YAML** que firma la imagen.
- La **policy de admission** (Kyverno ClusterPolicy o Ratify Verifier — elige una, la otra como ejercicio opcional).
- Un **README-INTENT.md** justificando decisiones.

**Importante**: no hay cluster AKS ni runner real. **No** se ejecuta ni `cosign sign` ni `kubectl apply`. Entregable: archivos YAML + Markdown.

## 3. Objetivos

Al terminar deberias poder:

- Escribir un `job` de GHA con `permissions: id-token: write` que firme sin ningun secret.
- Escribir una `ClusterPolicy` de Kyverno con `verifyImages` + `keyless` o un `Verifier` de Ratify equivalente.
- Explicar la diferencia entre `validationFailureAction: Enforce` y `Audit` y por que la primera es la correcta en prod.
- Pinnear `certificate-identity` a un workflow concreto (y no a un repo entero).

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` (§7 cosign, §8 admission) y los ejemplos 01 y 02.
- Herramientas: `bash`, `grep`, `python3`. Opcional: `yq` o `kubectl --dry-run=client` si quieres validar manualmente los YAML (no son requeridos por el validador).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-10-02/.github/workflows
mkdir -p /tmp/az-10-02/admission
cd /tmp/az-10-02
```

### 5.2 Escribe el workflow

Archivo: `/tmp/az-10-02/.github/workflows/build-sign-push.yml`.

Requisitos (el validador los busca):

- `permissions:` con `id-token: write` y `contents: read`.
- `uses: azure/login@...` (OIDC, sin `creds` ni `client-secret`).
- `uses: sigstore/cosign-installer@...`.
- Un paso `run:` o `uses:` que ejecute `cosign sign --yes ...` sobre una imagen cuyo tag incluya `${{ github.sha }}` o un digest.
- Debe hacer `docker/build-push-action@...` o `az acr build` o similar (push a `acrcheckoutprod.azurecr.io/checkout...`).
- **No** debe contener `client-secret`, `AZURE_CREDENTIALS`, ni `password:`.

### 5.3 Escribe la policy de admission

Elige **una** de las dos (no las dos; el validador acepta cualquiera):

#### Opcion A — Kyverno

Archivo: `/tmp/az-10-02/admission/kyverno-verify-signature.yaml`

Debe contener:

- `apiVersion: kyverno.io/...`
- `kind: ClusterPolicy`
- `validationFailureAction: Enforce` (literal).
- Bloque `verifyImages:` con `attestors:` -> `entries:` -> `keyless:`.
- Dentro de `keyless`, `subject:` que contenga `.github/workflows/build-sign-push.yml@refs/heads/main`.
- Dentro de `keyless`, `issuer: "https://token.actions.githubusercontent.com"`.

#### Opcion B — Ratify

Archivo: `/tmp/az-10-02/admission/ratify-verifier-cosign.yaml`

Debe contener:

- `apiVersion: config.ratify.deislabs.io/...`
- `kind: Verifier`
- `name: cosign` o similar bajo `spec:`.
- `certificate-identity: "https://github.com/<owner>/<repo>/.github/workflows/build-sign-push.yml@refs/heads/main"`.
- `certificate-oidc-issuer: "https://token.actions.githubusercontent.com"`.

### 5.4 Escribe `README-INTENT.md`

Secciones obligatorias:

- `## Pipeline de firma`
- `## Policy de admission`
- `## Excepciones y rollout`

Contenido minimo:

- Mencion explicita de **cosign** y de **keyless**.
- Mencion de **Rekor** (transparencia).
- Justificacion de `Enforce` vs `Audit`.
- Mencion de **ACR** y de **AKS**.
- **No** llames al archivo `ANALYSIS.md`.

### 5.5 Entregable

```
/tmp/az-10-02/
├── .github/workflows/build-sign-push.yml
├── admission/
│   └── (kyverno-verify-signature.yaml  OR  ratify-verifier-cosign.yaml)
└── README-INTENT.md
```

## 6. Resultado esperado

- `bash tests/validate.sh /tmp/az-10-02` termina con `OK:` y exit 0.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador en verde.
- **Correctitud**: YAML parseable; policy con `Enforce`; `certificate-identity` apunta a workflow concreto (no a repo entero).
- **Mantenibilidad**: labels, nombres consistentes.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/az-10-02
```

El validador comprueba **estructura y presencia de campos literales**. No ejecuta cosign, no monta AKS, no habla con Rekor.

## 9. Preguntas de reflexion

1. ¿Que falla si tu policy pinnea `.github/workflows/build.yml` y renombras el workflow a `build-sign-push.yml`?
2. ¿Por que `issuer: "https://token.actions.githubusercontent.com"` es obligatorio y no basta con `certificate-identity`?
3. ¿Que pasa en el cluster si Rekor publico esta caido? ¿Como lo mitigas?
4. ¿Por que en dev suele usarse `Audit` y en prod `Enforce`? ¿Que pierdes en Audit?
5. Un pod intenta correr `nginx:latest` (imagen publica). ¿Que decision toma tu policy y por que?

## 10. Extensiones

- Escribe la OTRA policy (si usaste Kyverno, escribe tambien la de Ratify).
- Anade a Kyverno un segundo `rule` que verifique un **SBOM** adjunto a la imagen (cosign attach sbom + Kyverno `verifyImages` con `attestations:`).
- Escribe un `pod-good.yaml` y un `pod-bad.yaml` para documentar el caso allow/deny (sin aplicar).

## 11. Limpieza

```bash
rm -rf /tmp/az-10-02
```

Nada que detener en cloud — no se desplego nada.
