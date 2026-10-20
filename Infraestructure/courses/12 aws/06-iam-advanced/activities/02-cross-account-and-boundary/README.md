# Actividad 02 — Boundary para developers + trust policy cross-account defendida

## 1. Identificación

- **ID:** `aws-06-02-cross-account-and-boundary`
- **Tecnología:** `aws`
- **Módulo:** `aws-06-iam-advanced`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** independent (no depende de la actividad 01)

## 2. Contexto

Dos problemas simultáneos:

1. **Delegación interna.** El admin de la cuenta `prod` quiere dejar que los developers creen roles para sus propias apps, pero sin que ninguno de esos roles pueda escalar a admin. Patrón `permission boundary`.
2. **Acceso cross-account.** Un equipo de datos en la cuenta A `111111111111` necesita leer un bucket en la cuenta B `222222222222`. Hay que escribir la trust policy del rol en B. Y además, hay un vendor externo (`arn:aws:iam::999999999999:root`, fuera de tu organización) que también necesita acceso para enviar métricas al mismo bucket.

Tu entregable es:

- Dos boundaries + policies en JSON.
- Dos trust policies cross-account (una intra-org, otra para vendor externo).
- Un documento `DECISIONS.md` que defienda las elecciones.

**No** se aplica nada en AWS. Validación estructural con `jq`.

## 3. Objetivos

- Diseñar un boundary que **permita el trabajo normal** del developer y **deniegue la escalada** (`iam:CreateUser`, `iam:AttachUserPolicy`, borrar el propio boundary, etc.).
- Escribir una trust policy intra-org con `aws:PrincipalOrgID` + MFA.
- Escribir una trust policy para vendor externo con `sts:ExternalId`.
- Explicar por qué `sts:ExternalId` es necesario para vendor y por qué `aws:PrincipalOrgID` no sirve en ese caso.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §3, §4 y §5.
- Haber recorrido `examples/02-permission-boundary-for-developers/` y `examples/03-cross-account-s3-trust/`.
- Herramientas: `bash`, `jq`.

**Costos**: cero.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-06-cross-account/policies
cd /tmp/aws-06-cross-account
```

### 5.2 Escribe cuatro JSON

- **`policies/boundary-dev.json`** — permission boundary para developers. Debe permitir operación runtime de apps (S3 lectura/escritura en `app-*`, SNS publish en `app-*`, logs) y **denegar** explícitamente `iam:CreateUser`, `iam:AttachUserPolicy`, `iam:PutUserPolicy`, `iam:CreateAccessKey`, `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`.
- **`policies/developer-identity.json`** — identity policy del developer. Permite `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:PassRole` sobre `arn:aws:iam::*:role/app-*`, **con la condition** `iam:PermissionsBoundary = <ARN del boundary>`.
- **`policies/trust-intra-org.json`** — trust policy del rol `CrossAccountReadReports` en cuenta B. Confía en cuenta A (`arn:aws:iam::111111111111:root`), con `aws:PrincipalOrgID` y MFA requerida.
- **`policies/trust-vendor-external.json`** — trust policy del rol `VendorMetricsIngest` en cuenta B. Confía en vendor (`arn:aws:iam::999999999999:root`), con `sts:ExternalId` requerido. **No** uses `aws:PrincipalOrgID` aquí (el vendor está fuera de tu org — fallaría).

### 5.3 Escribe `DECISIONS.md`

Con cinco secciones:

#### Sección A — Resumen

Qué escenarios estás resolviendo y por qué boundaries + trust policies son las herramientas correctas.

#### Sección B — Boundary de developers

- Qué permite (en 2-3 líneas).
- Qué deniega explícitamente y **qué ataque** previene cada deny (p. ej. `iam:DeleteRolePermissionsBoundary` previene que un rol creado por el developer remueva su propio techo).

#### Sección C — Identity policy del developer

- Explica la condition `iam:PermissionsBoundary`. ¿Qué pasa si falta?
- ¿Puede el developer crear un rol llamado `admin-of-me`? ¿Por qué no?

#### Sección D — Trust policy intra-org

- Qué condition keys usas y qué defienden cada una.
- ¿Qué pasaría si quitaras `aws:PrincipalOrgID`?

#### Sección E — Trust policy vendor externo

- Por qué `sts:ExternalId` es necesario.
- Por qué `aws:PrincipalOrgID` **no** aplica aquí.
- ¿Qué ataque concreto (confused deputy) previene `sts:ExternalId`?

### 5.4 Entregable

```
/tmp/aws-06-cross-account/
├── DECISIONS.md
└── policies/
    ├── boundary-dev.json
    ├── developer-identity.json
    ├── trust-intra-org.json
    └── trust-vendor-external.json
```

## 6. Resultado esperado

- Los cuatro JSON son válidos estructuralmente.
- `boundary-dev.json` tiene al menos un `Allow` y al menos un `Deny`; el `Deny` niega `iam:DeleteRolePermissionsBoundary` o `iam:DeleteUserPermissionsBoundary`.
- `developer-identity.json` contiene la clave `iam:PermissionsBoundary` en una `Condition`.
- `trust-intra-org.json` menciona `aws:PrincipalOrgID` y `sts:AssumeRole`.
- `trust-vendor-external.json` menciona `sts:ExternalId` y `sts:AssumeRole`.
- `DECISIONS.md` tiene las cinco secciones y responde las preguntas de §C, §D, §E.
- `bash tests/validate.sh /tmp/aws-06-cross-account` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada condition key está justificada contra un ataque concreto, no con "más seguro".
- **Reproducibilidad**: alguien que lea `DECISIONS.md` entiende por qué rechazaste `aws:PrincipalOrgID` para el vendor.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-06-cross-account
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si el developer tiene `AdministratorAccess` en su identity policy pero su boundary niega `iam:CreateUser`? ¿Puede crear usuarios?
2. ¿Por qué se dice que boundary + identity es un `AND`? ¿Cuál es el conjunto efectivo de permisos?
3. En la trust policy vendor, ¿qué pasa si pones un `ExternalId` que es público (p. ej. el nombre de tu cuenta)? ¿Para qué sirve en ese caso?
4. ¿Puede el admin de cuenta B saber qué cuenta A asumió el rol concretamente? ¿Dónde se audita?
5. Si cambias `Principal: {AWS: "arn:aws:iam::111111111111:root"}` por `Principal: {AWS: "arn:aws:iam::111111111111:user/alice"}`, ¿gana en seguridad o pierde en flexibilidad? ¿Qué eliges y por qué?

## 10. Extensiones

- Añade una tercera trust policy para un rol asumido por el servicio `codebuild.amazonaws.com` con `aws:SourceAccount` y `aws:SourceArn`.
- Diseña una session policy que, cuando Alice asuma `CrossAccountReadReports`, acote la sesión a *solo un prefijo* del bucket.
- Dibuja un diagrama ASCII en `DECISIONS.md` de los cinco techos aplicando sobre el request `s3:GetObject` cross-account.

## 11. Limpieza

```bash
rm -rf /tmp/aws-06-cross-account
```
