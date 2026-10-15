# Ejemplo 01 — Internal module registry vía Git tags

Publicar un módulo "golden" en un **bare git repo local** (que juega el papel de registry interno) y consumirlo con pin SemVer. Todo offline, sin red.

## Qué muestra

- Cómo se materializa un "registry interno" sin servicios externos: un bare repo en `/tmp/registry/<module>.git`.
- Cómo tagear un módulo con SemVer (`v1.0.0`, `v1.1.0`).
- Cómo consumirlo con `source = "git::file:///tmp/registry/local-greeter.git?ref=v1.0.0"`.
- La diferencia operativa de pinnear por tag vs rama.

## Estructura

```
examples/01-internal-module-registry-via-git-tags/
├── README.md
├── setup.sh              # publica el módulo en el bare repo local
├── cleanup.sh            # elimina /tmp/registry y /tmp/consumer-tf14-01
├── module-source/        # código fuente del módulo golden
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
└── consumer/             # stack que consume el módulo pinned por tag
    ├── main.tf
    └── versions.tf
```

## Prerrequisitos

- Terraform ≥ 1.5
- Git ≥ 2.30
- Shell POSIX

## Pasos

### 1. Publicar v1.0.0 en el "registry"

```bash
cd examples/01-internal-module-registry-via-git-tags
bash setup.sh
```

`setup.sh` hace:

1. Crea `/tmp/registry/local-greeter.git` como **bare repo**.
2. En un worktree temporal copia `module-source/`, hace `git init` + commit + tag `v1.0.0`, y empuja a `/tmp/registry/local-greeter.git`.
3. Prepara `/tmp/consumer-tf14-01/` copiando `consumer/`.

### 2. Consumir pinned a v1.0.0

```bash
cd /tmp/consumer-tf14-01
terraform init
terraform apply -auto-approve
```

Observa en `.terraform/modules/modules.json` que la resolución quedó fijada al commit del tag `v1.0.0`, no a `main`.

### 3. Publicar v1.1.0 y comprobar que el consumer no se mueve solo

Edita `module-source/main.tf` para añadir un sufijo (por ejemplo `-v2`) al mensaje y re-ejecuta la parte de release del setup:

```bash
# Simular una minor nueva
cd examples/01-internal-module-registry-via-git-tags
# (edita module-source/main.tf a tu gusto)
TAG=v1.1.0 bash setup.sh --release-only
```

Vuelve al consumer y haz `terraform plan`. **No debe haber cambios**: el consumer sigue en `v1.0.0`. Para adoptar la nueva versión, cambia el `?ref=v1.0.0` por `?ref=v1.1.0` y haz `terraform init -upgrade`.

### 4. Limpieza

```bash
bash cleanup.sh
```

## Decisiones de diseño

- **Bare repo local** en vez de servidor Git real: didáctico, cero dependencias, reproducible.
- **Protocolo `git::file://`**: Terraform lo trata igual que `git::https://`. Las lecciones de pinning, cache y SemVer son idénticas.
- **Módulo "golden" mínimo**: envuelve `local_file` con naming convention `greeting-<name>.txt` y tags obligatorios en el output. Suficiente para ilustrar el contrato (fija lo no negociable: naming + output estándar).

## Qué llevarte

Un registry interno **no requiere Artifactory ni HCP**. En su mínima expresión es: un repo Git + disciplina de tags SemVer + `source = "git::...?ref=vX.Y.Z"`. Eso es el contrato operativo. Lo demás (UI, discovery, gating de permisos) es ergonomía.
