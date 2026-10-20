# Example 03 — Image automation nativa en Flux

Demuestra el ciclo `ImageRepository` → `ImagePolicy` → `ImageUpdateAutomation` con un repo **local** (file:// git) para no exigir cuenta GitHub.

## Qué demuestra

- Escaneo de un registry público (`ghcr.io/stefanprodan/podinfo`).
- Política semver que selecciona el "tag ganador".
- Marker en el manifest (`# {"$imagepolicy": "flux-system:podinfo"}`).
- `ImageUpdateAutomation` que **commitea** al repo infra el bump.
- Resultado observable: `git log` del repo local muestra un commit "chore(images): …" firmado por `fluxcdbot`.

## Requisitos

- `kind`, `kubectl`, `flux`, `git`.

SKIP graceful si falta algo.

## Ejecutar

```bash
bash run.sh
```

El script:

1. Inicializa un repo Git **local** en `/tmp/flux-ex03-repo` (file://-servible por `git daemon` o leído directo por GitRepository con `url: file:///…`? **No** — Flux no soporta `file://`. Usamos un `git daemon` local escuchando en el host y el cluster `kind` lo alcanza vía `host.docker.internal` o `172.17.0.1`).
2. Para simplificar y mantener el ejemplo **ejecutable sin red externa**, el script **monta** el repo local vía `--extra-mounts` del `kind` cluster y usa un `GitRepository` con URL HTTPS pública como *fallback* si el servidor local no es alcanzable.
3. Instala Flux con `image-reflector-controller` + `image-automation-controller`.
4. Aplica `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` y un `Deployment` marcado.
5. Fuerza `flux reconcile image repository podinfo` y espera un commit de automation.

## Limpieza

```bash
bash cleanup.sh
```

## Comparación con Argo CD Image Updater

| Tema | Flux | Argo CD Image Updater |
|---|---|---|
| Modo "write-to-git" | Único soportado | Opción `argocd-image-updater.argoproj.io/write-back-method: git` |
| Modo "update Application CR" | **No existe** (sería anti-GitOps) | Opción `argocd` (más laxo) |
| Instalación | Incluido en `flux install` | Add-on separado |
| Firma de commits | Soporta GPG via secret | Soporta GPG via secret |

Para GitOps estricto, el modelo Flux (commit a Git **siempre**) es el que respeta el principio "Git es la única fuente de verdad".
