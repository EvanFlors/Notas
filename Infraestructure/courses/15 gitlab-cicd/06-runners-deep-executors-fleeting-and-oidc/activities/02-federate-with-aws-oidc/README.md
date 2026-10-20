# Actividad 02 — Federar GitLab con AWS por OIDC

## 1. Identificación

- **ID:** `gl-06-02-federate-with-aws-oidc`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-06-runners-deep-executors-fleeting-and-oidc`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** independent (walkthrough — sin dependencia de la actividad 01)

## 2. Contexto

Tu equipo quiere eliminar los `AWS_ACCESS_KEY_ID` del proyecto `acme/web` en GitLab. Deben:

- Publicar artefactos a `s3://acme-web-prod` **solo** desde `main` del proyecto `acme/web`, y **solo** en el environment `production`.
- Nadie más del group `acme` debe poder asumir ese role (ni siquiera accidentalmente).
- No se deben almacenar credenciales de larga vida en Variables de GitLab.

Vas a producir **tres artefactos** en `/tmp/gl-06-oidc/`:

- `trust-policy.json` — la trust policy del IAM role `gitlab-deployer-prod`.
- `.gitlab-ci.yml` — el pipeline consumidor con `id_tokens:`.
- `README-INTENT.md` — justificación del pinning y por qué no usar wildcards.

No vas a crear el role ni el provider en AWS. Es un **walkthrough**: los artefactos quedan listos para pegar en Fase 4.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar la diferencia entre `StringEquals` y `StringLike` sobre `sub`.
- Enumerar los claims clave (`iss`, `aud`, `sub`, `project_path`, `ref`, `environment`).
- Escribir el pipeline que ejerce `sts assume-role-with-web-identity`.
- Detectar un pinning inseguro (p. ej. `project_path:acme/*`) y proponer uno mejor.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 7, 8, 9).
- Haber recorrido `../../examples/03-oidc-id-token-to-aws/`.
- Herramientas: `bash`, `jq`, `python3` (`yaml` de stdlib). No se necesita cuenta AWS.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gl-06-oidc
cd /tmp/gl-06-oidc
```

### 5.2 Escribe `trust-policy.json`

Mínimo que exige el validador:

- `Version` = `"2012-10-17"`.
- `Statement[].Effect` = `"Allow"`.
- `Statement[].Action` incluye `"sts:AssumeRoleWithWebIdentity"`.
- `Principal.Federated` **ARN** apuntando a un `oidc-provider/gitlab.com` (o `/gitlab.*`).
- `Condition.StringEquals["gitlab.com:aud"]` igual a `"https://gitlab.com"` (o la URL de self-managed; cualquier valor no `*`).
- `Condition.StringLike["gitlab.com:sub"]` que contenga **ambos**:
  - `project_path:acme/web`
  - `ref:main`
- El `sub` **no** puede ser `"*"` ni empezar por `"*"` (el validador lo rechaza).

### 5.3 Escribe `.gitlab-ci.yml`

Mínimo:

- `stages:` con al menos `deploy`.
- Un job con:
  - `id_tokens:` que declare al menos un token con `aud:`.
  - `environment:` con `name: production` (para que el `sub` incluya `environment:production`).
  - `rules:` que lo limiten a `$CI_COMMIT_BRANCH == "main"` (o equivalente).
  - `script:` que invoque `aws sts assume-role-with-web-identity` usando `--web-identity-token "$<nombre_id_token>"`.
- **No** debe declarar `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` como `variables:` del `.gitlab-ci.yml` (el validador lo rechaza).

### 5.4 Escribe `README-INTENT.md`

Secciones obligatorias (encabezados que el validador busca):

1. `## Trust policy — pinning` — explica `aud`, `sub`, `project_path`, `ref`, `environment` con tu propio texto.
2. `## Antipatrones` — lista al menos 2 antipatrones de pinning (p. ej. `sub: *`, `project_path:acme/*` para roles con escritura).
3. `## Pipeline consumidor` — qué hace el job, qué variables **ya no** necesitas, qué duración de sesión pides.

Debe mencionar:

- `StringLike` y `StringEquals` (comparación).
- `AssumeRoleWithWebIdentity`.
- `protected environments` o `approval rules` (como capa adicional).

### 5.5 Entregables

```
/tmp/gl-06-oidc/
├── trust-policy.json
├── .gitlab-ci.yml
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 archivos existen y son parseables.
- La trust policy pinada por `project_path` + `ref`.
- El `.gitlab-ci.yml` no contiene credenciales estáticas.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: `README-INTENT.md` razona el pinning y los antipatrones.
- **Seguridad**: `sub` lo bastante estricto para que `acme/web` sea el único consumidor.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-06-oidc
```

El validador comprueba **estructura y señales mínimas**. No crea ningún recurso AWS. Compara con `solution/` para autoevaluación semántica.

## 9. Preguntas de reflexión

1. ¿Qué `sub` escribirías si quisieras permitir `main` **y** cualquier tag `v*.*.*`? ¿Un solo `Statement` o dos?
2. Si el equipo ya usa Vault con ID Tokens, ¿necesitas un `aud:` distinto por destino? ¿Por qué?
3. ¿Qué pasa si olvidas `environment:` en el job pero la trust policy exige `environment:production`?
4. Si el proyecto se mueve de group (`acme/web` → `platform/web`), ¿qué rompe primero y cómo lo detectas en el pipeline?

## 10. Extensiones

- Añade un segundo role de **readonly** con pinning laxo (`project_path:acme/*`) para `aws s3 ls` desde cualquier proyecto del group.
- Añade un job de "debug-sub" que imprima los claims del JWT (fuera de prod, con `rules:` que lo limiten a MR a `main`).

## 11. Limpieza

```bash
rm -rf /tmp/gl-06-oidc
```
