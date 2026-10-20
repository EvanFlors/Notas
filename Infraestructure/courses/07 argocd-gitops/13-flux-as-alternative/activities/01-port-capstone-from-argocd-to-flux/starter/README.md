# Starter — argo-13-01

Esta actividad es **independiente**. No hay andamiaje de código: tú decides la implementación.

## Qué deberías tener listo antes de empezar

- Un cluster `kind` operativo (`kind create cluster --name argo-13-01`).
- `kubectl` apuntando a ese cluster.
- `flux` CLI instalado (`brew install fluxcd/tap/flux`).
- Idealmente, acceso al chart/manifests de tu capstone de `argo-04`. Si no, usa `podinfo` como stand-in (ver README principal, opción B).

## Esqueleto sugerido para `solution/`

```
solution/
├── README-port.md      # TUS decisiones (no copies el README principal)
├── manifests.yaml      # GitRepository|HelmRepository + HelmRelease|Kustomization
└── run.sh              # idempotente, instala flux y aplica manifests.yaml
```

Cuando termines, corre `bash ../tests/validate.sh` desde el directorio de la actividad.
