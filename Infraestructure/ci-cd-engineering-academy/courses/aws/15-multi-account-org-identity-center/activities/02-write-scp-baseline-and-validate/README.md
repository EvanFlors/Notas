# Actividad 02 — Escribir SCPs del baseline y validarlas

## 1. Identificación

- **ID:** `aws-15-02-write-scp-baseline-and-validate`
- **Tecnología:** `aws`
- **Módulo:** `aws-15-multi-account-org-identity-center`
- **Dificultad:** advanced
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de Security te pide escribir el **baseline de SCPs** de la organización. Son tres políticas que todas las cuentas de la org deben tener aplicadas (directa o heredadamente). No vas a adjuntarlas a nada: estás **escribiéndolas** para que Fase 4 las aplique con Terraform. Deben ser JSON válido, respetar la sintaxis de SCPs, y venir acompañadas de un documento que explique qué deniega cada una, dónde se adjuntará y qué excepciones contempla.

**Importante**: no hay cuenta AWS. No se aplica nada. El entregable son 3 archivos JSON + 1 README.

## 3. Objetivos

Al terminar deberías poder:

- Escribir una SCP sintácticamente correcta usando `Version`, `Statement`, `Effect`, `Action`/`NotAction`, `Resource`, `Condition`.
- Explicar por qué el `deny-regions` necesita `NotAction` para los servicios globales.
- Nombrar las acciones de CloudTrail y Config que `deny-disable-logging` debe proteger.
- Justificar por escrito dónde adjuntar cada SCP (OU vs cuenta).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§4 y §5) y recorrido `../../examples/02-scp-anatomy/`.
- Herramientas: `bash`, `jq` (parser JSON), `python3` (opcional, validación extra). Un editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-15-scp
cd /tmp/aws-15-scp
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 3 archivos JSON

Nombres **exactos** (el validador los busca):

1. `scp-deny-regions.json`
2. `scp-deny-leave-org.json`
3. `scp-deny-disable-logging.json`

Requisitos por archivo:

#### `scp-deny-regions.json`

- `Version` == `"2012-10-17"`.
- Al menos un `Statement` con `Effect: "Deny"`.
- Debe usar `NotAction` (no `Action`) — porque el patrón es "deniega **excepto** servicios globales".
- `NotAction` debe listar al menos: `iam:*`, `organizations:*`, `cloudfront:*`, `route53:*`, `support:*`, y alguna acción de `sts:*`.
- `Resource: "*"`.
- `Condition` con `StringNotEquals` sobre `aws:RequestedRegion`, listando al menos una región europea (`eu-west-1`, `eu-central-1`, etc.).

#### `scp-deny-leave-org.json`

- `Version` == `"2012-10-17"`.
- `Statement` con `Effect: "Deny"`.
- `Action` debe contener `organizations:LeaveOrganization`.
- `Resource: "*"`.

#### `scp-deny-disable-logging.json`

- `Version` == `"2012-10-17"`.
- Uno o más `Statement` con `Effect: "Deny"`.
- Debe denegar al menos 3 acciones destructivas de **CloudTrail**: `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, y una tercera (`UpdateTrail`, `PutEventSelectors`, etc.).
- Debe denegar al menos 2 acciones destructivas de **Config**: `config:StopConfigurationRecorder`, `config:DeleteConfigurationRecorder`, u otras.

Los tres archivos deben ser **JSON válido** (parseables por `jq .`).

### 5.3 Escribe `README-INTENT.md`

Un documento que explique, para cada SCP:

- **Qué deniega** (en lenguaje humano, no copiando el JSON).
- **A qué OU se adjuntará** y por qué (Root, Workloads, Security…).
- **Qué excepciones** hay (p. ej. roles de BreakGlass) o por qué no las hay.
- Para `deny-regions`, un párrafo justificando por qué `NotAction` para servicios globales.
- Para `deny-disable-logging`, mención explícita de **CloudTrail** y **Config**.

Secciones obligatorias (el validador las busca):

- `## scp-deny-regions`
- `## scp-deny-leave-org`
- `## scp-deny-disable-logging`

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.4 Entregables

```
/tmp/aws-15-scp/
├── scp-deny-regions.json
├── scp-deny-leave-org.json
├── scp-deny-disable-logging.json
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 JSONs parsean con `jq .`.
- El validador pasa en verde:
  - sintaxis JSON de cada archivo,
  - presencia de `Version`, `Statement`, `Effect: Deny`,
  - presencia de las condiciones/acciones mínimas por SCP,
  - presencia del `README-INTENT.md` con las 3 secciones.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud sintáctica**: JSON válido, strings bien cerradas, comas correctas.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: `Sid` legible, campos ordenados consistentemente.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-15-scp
```

El validador comprueba sintaxis JSON y presencia de claves/acciones mínimas. **No** comprueba que la SCP, aplicada a una cuenta real, haga exactamente lo que dice el README. Esa validación semántica se hace en Fase 4 contra una org real (con el *simulator* de IAM y con cuentas de prueba).

## 9. Preguntas de reflexión

1. Si quitas `sts:AssumeRole` del `NotAction` de `deny-regions`, ¿qué deja de funcionar?
2. ¿Puedes aplicar `deny-leave-organization` a la management account? ¿Qué pasaría?
3. ¿Por qué `deny-disable-logging` necesita proteger también el bucket S3 central de logs, no solo los servicios CloudTrail/Config?
4. ¿Cómo probarías una SCP sin arriesgarte a romper prod? (pista: Sandbox OU + dry-run con IAM policy simulator).
5. Si un desarrollador necesita trabajar temporalmente en `us-east-1`, ¿cómo le concedes acceso sin desactivar la SCP?

## 10. Extensiones

- Añade una cuarta SCP: `scp-deny-public-s3.json` que impida `s3:PutBucketAcl` con `public-read`/`public-read-write` y bloquee `s3:PutBucketPolicy` que abra el bucket.
- Añade una SCP `scp-require-mfa-destructive.json` usando `aws:MultiFactorAuthPresent: false` para denegar deletes de RDS/EBS/S3 sin MFA.
- Escribe un pequeño script `verify-scp.sh` que corra `jq` + comprobaciones adicionales (p. ej. que todas las SCPs tengan `Version 2012-10-17`).

## 11. Limpieza

```bash
rm -rf /tmp/aws-15-scp
```

No hay infraestructura que detener.
