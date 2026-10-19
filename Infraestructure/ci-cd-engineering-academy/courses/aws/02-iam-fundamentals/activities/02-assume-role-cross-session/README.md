# Actividad 02 — Cadena de asumción de roles: SSO → OperatorRole → ProdS3Admin

## 1. Identificación

- **ID:** `aws-02-02-assume-role-cross-session`
- **Tecnología:** `aws`
- **Módulo:** `aws-02-iam-fundamentals`
- **Dificultad:** beginner
- **Duración estimada:** 60–75 min
- **Tipo:** independent

## 2. Contexto

Reutilizamos el escenario del `examples/02-role-assume-chain/`: Alice (SSO) tiene que operar sobre S3 en una cuenta de **producción** distinta. La organización monta una cadena en dos saltos:

1. Alice (SSO en cuenta hub `111111111111`) asume `OperatorRole` en la misma cuenta — paso que exige MFA.
2. `OperatorRole` asume `ProdS3Admin` en la cuenta de producción `222222222222` — paso protegido con `sts:ExternalId`.
3. `ProdS3Admin`, ya en producción, puede operar S3 solo bajo buckets `acme-prod-*`.

Tu trabajo: materializar las **tres piezas JSON** (dos trust policies + una permission policy mínima) y documentar la cadena para que una persona nueva pueda reproducirla sin ambigüedad.

**No se despliega nada.** Todo es análisis + JSON validado estructuralmente. No cuesta nada.

## 3. Objetivos

- Escribir el **trust policy** de `OperatorRole` que acepta a Alice (o, en general, al permission set Developer de la cuenta hub) **con MFA**.
- Escribir el **trust policy** de `ProdS3Admin` que acepta solo al `OperatorRole` como principal y usa **`sts:ExternalId`**.
- Escribir la **permission policy** mínima de `ProdS3Admin` acotada a los buckets `acme-prod-*`.
- Documentar en `SESSION.md` qué hace STS en cada salto, qué queda en CloudTrail y por qué el diseño es más seguro que `S3FullAccess` directo a Alice.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en especial §5) y el `examples/02-role-assume-chain/`.
- `python3` (3.8+) para validar JSON.

**Costos**: cero. Nada se provisiona.

## 5. Instrucciones

### 5.1 Prepara el scratch dir

```bash
mkdir -p /tmp/aws-02-chain
cd /tmp/aws-02-chain
```

### 5.2 Crea los tres JSON

Tres archivos exactamente con estos nombres:

- **`TRUST_OPERATOR.json`** — trust policy de `OperatorRole` (cuenta hub `111111111111`).
  - Action: `sts:AssumeRole`.
  - Principal: `arn:aws:iam::111111111111:root` (o un principal más estricto si quieres).
  - Condition: debe exigir MFA (`aws:MultiFactorAuthPresent`).
- **`TRUST_PROD.json`** — trust policy de `ProdS3Admin` (cuenta prod `222222222222`).
  - Action: `sts:AssumeRole`.
  - Principal: `arn:aws:iam::111111111111:role/OperatorRole` (**el rol**, no la cuenta entera).
  - Condition: debe incluir `sts:ExternalId` con un valor compartido.
- **`PERM_PROD.json`** — permission policy de `ProdS3Admin`.
  - Permisos mínimos S3 (list, get, put, delete) acotados a `arn:aws:s3:::acme-prod-*` y sus objetos.
  - **Prohibido**: `"Action": "*"`, `"Action": "s3:*"`, `"Resource": "*"`.

Para los **account IDs usa los placeholders `111111111111` y `222222222222` o `123456789012`**. Nunca pongas un ID real. Para el `ExternalId` usa un valor obviamente de ejemplo (p. ej. `acme-prod-handshake-7f9c`), nunca un valor que pudieras usar en producción real.

### 5.3 Crea `SESSION.md`

Secciones mínimas:

1. **`## Cadena`** — un diagrama ASCII (sirve el del ejemplo, adaptado) con los 3 saltos y el actor en cada caso.
2. **`## Qué hace STS en cada salto`** — por cada `AssumeRole`, 2–4 líneas: qué principal es el *caller*, qué política evalúa STS, qué devuelve, cuánto dura la sesión.
3. **`## Trazas en CloudTrail`** — qué eventos esperas, qué contiene `userIdentity.arn` tras cada salto, cómo relacionas las operaciones S3 finales con la humana original.
4. **`## Por qué este diseño y no "S3FullAccess a Alice"`** — 4–6 bullets argumentando (blast radius, auditoría, cero access keys, separación por entorno, etc.).
5. **`## Rol del ExternalId`** — un párrafo explicando el ataque del *confused deputy* y por qué `sts:ExternalId` lo mitiga.

### 5.4 Validar

```bash
bash <repo>/courses/aws/02-iam-fundamentals/activities/02-assume-role-cross-session/tests/validate.sh /tmp/aws-02-chain
```

El validador:

- Comprueba que los **tres `*.json`** parsean con `python3 json.load`.
- `TRUST_OPERATOR.json`: `Action: sts:AssumeRole`, menciona `111111111111`, Condition con `aws:MultiFactorAuthPresent`.
- `TRUST_PROD.json`: `Action: sts:AssumeRole`, principal menciona `OperatorRole`, Condition con `sts:ExternalId`.
- `PERM_PROD.json`: no contiene wildcards peligrosos, menciona `acme-prod` en los ARNs, incluye `s3:ListBucket` y `s3:GetObject`.
- Comprueba que **no aparecen account IDs reales** (12 dígitos distintos de `111111111111`, `222222222222`, `123456789012`). Si aparecen, falla con mensaje claro.
- Comprueba `SESSION.md` con sus 5 secciones y menciones a `STS`, `CloudTrail`, `ExternalId`, `MFA`.

### 5.5 Limpieza

```bash
rm -rf /tmp/aws-02-chain
```

## 6. Resultado esperado

- Tres JSON válidos y coherentes con el escenario.
- `SESSION.md` con las 5 secciones.
- `validate.sh` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: trust policies plausibles para una cadena real.
- **Seguridad**: `ExternalId` presente, MFA exigida, no account IDs reales, no wildcards de más.
- **Reproducibilidad**: alguien ajeno puede reconstruir el escenario leyendo `SESSION.md`.
- **Mantenibilidad**: Sids con nombre, un statement por responsabilidad.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-02-chain
```

Para autoevaluación profunda, compara contra `solution/REFERENCE.md` y `solution/TEMPLATE.md`.

## 9. Preguntas de reflexión

1. ¿Qué cambia si en la trust policy de `ProdS3Admin` pones como `Principal` toda la cuenta `111111111111:root` en vez del rol concreto?
2. Si Alice pierde su MFA, ¿puede todavía asumir `OperatorRole`? ¿Y `ProdS3Admin` directamente desde el SSO?
3. ¿Por qué un `ExternalId` **no** sustituye a los permisos: qué ataque específico cubre que la trust policy sola no cubriría?
4. Si quisieras que `OperatorRole` pudiera asumir también un `ProdDBAdmin` en la cuenta prod, ¿añades un statement nuevo en su permission policy o duplicas el rol? ¿Pros y contras?
5. ¿Qué duración de sesión (`DurationSeconds` en `AssumeRole`) pedirías para `ProdS3Admin`? ¿Por qué no 12 h?

## 10. Extensiones

- Añade un `Condition` con `aws:PrincipalTag/sso-role` en el trust de `OperatorRole` para restringir solo a usuarios SSO con tag `sso-role=Developer`.
- Modela un tercer rol `ProdS3ReadOnly` con solo `s3:ListBucket` y `s3:GetObject`, también asumible por `OperatorRole`, y describe cuándo el operador escoge uno u otro.
- Diseña la equivalente OIDC: en vez de un humano SSO, un workflow de GitHub Actions como punto de entrada que llega hasta `ProdS3Admin`. ¿Qué cambia?

## 11. Limpieza

```bash
rm -rf /tmp/aws-02-chain
```
